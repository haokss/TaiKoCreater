#include <QGuiApplication>
#include <QCoreApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDir>
#include <QTextStream>
#include <QStringConverter>
#include "../core/SongScanner.h"
#include "../core/SongModel.h"
#include "../core/TjaValidator.h"
#include "../ai/DeepSeekClient.h"
#include "../services/AudioPlayer.h"
#include "../services/AppleMusicClient.h"
#include "../utils/Logger.h"
#include "../utils/ToastManager.h"

// ═══════════════════════════════════════════════════════════════════
// headless 入口：不开窗口也能跑谱面校验
//   SongSorter.exe --validate <file.tja>
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
        << "  " << argv0 << "                          启动 GUI\n"
        << "  " << argv0 << " --validate <file.tja>    校验谱面（无窗口）\n";
    out.flush();
    return 2;
}

int main(int argc, char *argv[])
{
    // 先处理 CLI 分支，避免创建 GUI 应用
    QStringList cliArgs;
    cliArgs.reserve(argc - 1);
    for (int i = 1; i < argc; ++i)
        cliArgs << QString::fromLocal8Bit(argv[i]);

    const int validateIdx = cliArgs.indexOf(QStringLiteral("--validate"));
    if (validateIdx >= 0)
    {
        if (validateIdx + 1 >= cliArgs.size())
            return runUsage(argv[0]);
        return runValidateCli(argc, argv, cliArgs.at(validateIdx + 1));
    }
    if (cliArgs.contains(QStringLiteral("--help")) || cliArgs.contains(QStringLiteral("-h")))
        return runUsage(argv[0]);

    QGuiApplication app(argc, argv);
    QQmlApplicationEngine engine;

    QObject::connect(
        &engine,
        &QQmlEngine::warnings,
        [](const QList<QQmlError> &warnings)
        {
            for (auto &e : warnings)
                qDebug() << e.toString();
        });

    QList<SongInfo> emptyList;
    SongModel *songModel = new SongModel(&engine);
    // 不调用 setSongs，用空链表初始构造
    songModel->setSongs(emptyList, QString());

    DeepSeekClient *deepSeek = new DeepSeekClient(&engine);

    AudioPlayer *audioPlayer = new AudioPlayer(&engine);
    engine.rootContext()->setContextProperty("audioPlayer", audioPlayer);

    AppleMusicClient *appleMusic = new AppleMusicClient(&engine);
    engine.rootContext()->setContextProperty("appleMusic", appleMusic);
    engine.rootContext()->setContextProperty("logger", Logger::instance());
    engine.rootContext()->setContextProperty("songModel", songModel);
    engine.rootContext()->setContextProperty("deepSeek", deepSeek);
    engine.rootContext()->setContextProperty("toastManager", ToastManager::instance());

    Logger::log("App", "应用程序启动");

    // 添加 ui/ 模块搜索路径
    engine.addImportPath(QCoreApplication::applicationDirPath());

    QString qmlPath = QCoreApplication::applicationDirPath() + QDir::separator() + "main.qml";
    engine.load(QUrl::fromLocalFile(qmlPath));

    if (engine.rootObjects().isEmpty())
        return -1;

    QString defaultPath = "D:/TaikoNijiiroDondaEX Ver4.1/TaikoNijiiroDondaEX Ver4.1";

    QDir testDir(defaultPath + "/Songs");
    if (testDir.exists())
    {
        Logger::log("App", "检测到默认路径，异步加载: " + defaultPath);
        songModel->setRootPathAsync(defaultPath);
    }

    return app.exec();
}
