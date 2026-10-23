#include <QCoreApplication>
#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QMutex>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QStringConverter>
#include <QTextStream>

#include "QmlLiveReload.h"
#include "../ai/DeepSeekClient.h"
#include "../core/SongModel.h"
#include "../core/SongScanner.h"
#include "../core/TjaValidator.h"
#include "../services/AppleMusicClient.h"
#include "../services/AudioPlayer.h"
#include "../utils/Logger.h"
#include "../utils/ToastManager.h"

#ifdef Q_OS_WIN
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <cstdio>
#endif

// ═══════════════════════════════════════════════════════════════════
// 命令行选项
//   --validate <file.tja>   headless 校验谱面
//   --dev                   QML 热重载开发模式（从源码目录加载）
//   --qml-dir <path>        指定 QML 源目录（默认自动探测 exe 的上一级）
//   --no-watch              只看 --dev 的加载路径，不监视文件
// ═══════════════════════════════════════════════════════════════════
struct CliOptions
{
    bool dev = false;
    bool watch = true;
    bool help = false;
    QString validatePath;
    QString qmlDir;
};

static CliOptions parseCli(const QStringList &args)
{
    CliOptions opt;
    for (int i = 0; i < args.size(); ++i)
    {
        const QString &arg = args.at(i);
        if (arg == QLatin1String("--validate") && i + 1 < args.size())
            opt.validatePath = args.at(++i);
        else if (arg == QLatin1String("--dev"))
            opt.dev = true;
        else if (arg == QLatin1String("--no-watch"))
            opt.watch = false;
        else if (arg == QLatin1String("--qml-dir") && i + 1 < args.size())
            opt.qmlDir = args.at(++i);
        else if (arg == QLatin1String("--help") || arg == QLatin1String("-h"))
            opt.help = true;
    }
    return opt;
}

// 开发模式下尝试附着控制台（失败也无所谓，日志一律写 dev.log）
static void enableDevConsole()
{
#ifdef Q_OS_WIN
    if (!AttachConsole(ATTACH_PARENT_PROCESS))
        AllocConsole();
    SetConsoleTitleW(L"SongSorter --dev");
#endif
}

// 过滤掉第三方组件的噪音，只保留自己的标记与真正的告警
static bool isDevNoise(const QString &msg)
{
    static const char *const noise[] = {
        "customization of this control",      // Controls 样式自定义提示
        "is deprecated. Use this syntax instead", // Connections 隐式 onFoo 弃用
        "QML Connections: Implicitly defined",
    };
    for (const char *needle : noise)
    {
        if (msg.contains(QLatin1String(needle)))
            return true;
    }
    if (msg.contains(QLatin1String("[live]")) || msg.contains(QLatin1String("[dev]")))
        return false;
    // 其余 debug/info 一律不记，避免重载时刷屏
    return true;
}

// 开发模式日志同时落盘（exe 同目录 dev.log），控制台关了也能回看
static void devMessageHandler(QtMsgType type, const QMessageLogContext &, const QString &msg)
{
    if (isDevNoise(msg))
        return;

    static QMutex mutex;
    QMutexLocker locker(&mutex);

    static QFile logFile;
    static bool tried = false;
    if (!tried)
    {
        tried = true;
        logFile.setFileName(QDir(QCoreApplication::applicationDirPath()).filePath(QStringLiteral("dev.log")));
        logFile.open(QIODevice::Append | QIODevice::Text);
        // 打不开就静默放弃：切不可在这里再 qWarning，否则递归进 handler 直接爆栈
    }

    const char *level = "INFO ";
    if (type == QtWarningMsg)
        level = "WARN ";
    else if (type == QtCriticalMsg)
        level = "CRIT ";
    else if (type == QtFatalMsg)
        level = "FATAL";

    const QString line = QStringLiteral("%1 [%2] %3\n")
                             .arg(QDateTime::currentDateTime().toString(QStringLiteral("HH:mm:ss")),
                                  QLatin1String(level), msg);

    if (logFile.isOpen())
    {
        logFile.write(line.toUtf8());
        logFile.flush();
    }
}

// 探测 QML 源目录：显式指定 > exe 的上一级（release/..）> 失败
static QString resolveDevQmlDir(const QString &explicitDir, QString *error)
{
    if (!explicitDir.isEmpty())
    {
        const QString dir = QDir(explicitDir).absolutePath();
        if (QFile::exists(QDir(dir).filePath(QStringLiteral("main.qml"))))
            return dir;
        *error = QStringLiteral("--qml-dir 下没有 main.qml: %1").arg(dir);
        return QString();
    }

    const QDir exeDir(QCoreApplication::applicationDirPath());
    const QString parent = QDir::cleanPath(exeDir.filePath(QStringLiteral("..")));
    if (QFile::exists(QDir(parent).filePath(QStringLiteral("main.qml"))))
        return parent;

    *error = QStringLiteral("自动探测源码目录失败，请用 --qml-dir 指定 main.qml 所在目录");
    return QString();
}

// ═══════════════════════════════════════════════════════════════════
// headless：SongSorter.exe --validate <file.tja>
// 退出码：0 = 通过（可带警告），1 = 存在错误，2 = 用法错误
// ═══════════════════════════════════════════════════════════════════
static int runValidateCli(int argc, char *argv[], const QString &filePath)
{
    QCoreApplication app(argc, argv);

    QList<TjaProblem> problems;
    const ChartView view = TjaValidator::validateFile(filePath, &problems);

    QTextStream out(stdout);
    out.setEncoding(QStringConverter::Utf8);
    out << "文件: " << filePath << "\n";
    out << TjaValidator::reportText(view, problems);
    out.flush();

    return view.ok ? 0 : 1;
}

static int runUsage(const char *argv0)
{
    QTextStream out(stdout);
    out.setEncoding(QStringConverter::Utf8);
    out << "用法:\n"
        << "  " << argv0 << "                              启动 GUI\n"
        << "  " << argv0 << " --validate <file.tja>        校验谱面（无窗口）\n"
        << "  " << argv0 << " --dev                        开发模式：从源码目录加载 QML 并热重载\n"
        << "  " << argv0 << " --dev --qml-dir <dir>        指定 QML 源目录\n"
        << "  " << argv0 << " --dev --no-watch             只改加载路径，不监视文件变更\n";
    out.flush();
    return 2;
}

int main(int argc, char *argv[])
{
    QStringList cliArgs;
    cliArgs.reserve(qMax(0, argc - 1));
    for (int i = 1; i < argc; ++i)
        cliArgs << QString::fromLocal8Bit(argv[i]);
    const CliOptions opt = parseCli(cliArgs);

    if (opt.help)
        return runUsage(argv[0]);
    if (!opt.validatePath.isEmpty())
        return runValidateCli(argc, argv, opt.validatePath);

    QGuiApplication app(argc, argv);

    if (opt.dev)
    {
        enableDevConsole();
        qInstallMessageHandler(devMessageHandler);
        qInfo().noquote() << "===== dev 会话开始 =====";
    }

    QString qmlDir = QCoreApplication::applicationDirPath();
    if (opt.dev)
    {
        QString error;
        qmlDir = resolveDevQmlDir(opt.qmlDir, &error);
        if (qmlDir.isEmpty())
        {
            qWarning().noquote() << "[dev]" << error;
            return -1;
        }
        qInfo().noquote() << "[dev] QML 源目录:" << QDir::toNativeSeparators(qmlDir);
        qInfo().noquote() << "[dev] 修改 QML 后直接存盘即可，无需重新编译";
    }

    QQmlApplicationEngine engine;

    QObject::connect(
        &engine,
        &QQmlEngine::warnings,
        [](const QList<QQmlError> &warnings)
        {
            for (auto &e : warnings)
                qDebug() << e.toString();
        });

    // 业务对象挂在 app 上，而不是 engine 上：热重载销毁根对象时状态不丢
    SongModel *songModel = new SongModel(&app);
    songModel->setSongs(QList<SongInfo>(), QString());
    DeepSeekClient *deepSeek = new DeepSeekClient(&app);
    AudioPlayer *audioPlayer = new AudioPlayer(&app);
    AppleMusicClient *appleMusic = new AppleMusicClient(&app);

    engine.rootContext()->setContextProperty("audioPlayer", audioPlayer);
    engine.rootContext()->setContextProperty("appleMusic", appleMusic);
    engine.rootContext()->setContextProperty("logger", Logger::instance());
    engine.rootContext()->setContextProperty("songModel", songModel);
    engine.rootContext()->setContextProperty("deepSeek", deepSeek);
    engine.rootContext()->setContextProperty("toastManager", ToastManager::instance());

    Logger::log("App", "应用程序启动");

    engine.addImportPath(qmlDir);

    const QUrl entryUrl = QUrl::fromLocalFile(QDir(qmlDir).filePath(QStringLiteral("main.qml")));
    engine.load(entryUrl);

    if (engine.rootObjects().isEmpty())
        return -1;

    QmlLiveReload *liveReload = nullptr;
    if (opt.dev && opt.watch)
    {
        liveReload = new QmlLiveReload(&engine, entryUrl, &app);
        liveReload->watch(qmlDir);
    }

    QString defaultPath = "D:/TaikoNijiiroDondaEX Ver4.1/TaikoNijiiroDondaEX Ver4.1";

    QDir testDir(defaultPath + "/Songs");
    if (testDir.exists())
    {
        Logger::log("App", "检测到默认路径，异步加载: " + defaultPath);
        songModel->setRootPathAsync(defaultPath);
    }

    return app.exec();
}
