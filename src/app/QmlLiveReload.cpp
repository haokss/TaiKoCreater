#include "QmlLiveReload.h"

#include <QDebug>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QFileSystemWatcher>
#include <QQmlApplicationEngine>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQmlError>
#include <QSet>
#include <QTimer>

QmlLiveReload::QmlLiveReload(QQmlApplicationEngine *engine, const QUrl &entryUrl, QObject *parent)
    : QObject(parent)
    , m_engine(engine)
    , m_entryUrl(entryUrl)
    , m_watcher(new QFileSystemWatcher(this))
    , m_debounce(new QTimer(this))
{
    m_debounce->setSingleShot(true);
    m_debounce->setInterval(120); // 编辑器一次保存常触发多个事件，合并一下
    connect(m_debounce, &QTimer::timeout, this, &QmlLiveReload::performReload);

    connect(m_watcher, &QFileSystemWatcher::fileChanged, this, [this](const QString &path) {
        qInfo().noquote() << "[live] 文件变更:" << QDir::toNativeSeparators(path);
        m_pending.insert(QFileInfo(path).absoluteFilePath());
        scheduleReload();
    });
    connect(m_watcher, &QFileSystemWatcher::directoryChanged, this, [this](const QString &path) {
        // 目录事件多半是新建/删除/改名，把该目录下的 qml 都标记为待检查
        const QDir dir(path);
        const QStringList qmls = dir.entryList(QStringList() << QStringLiteral("*.qml"), QDir::Files);
        for (const QString &name : qmls)
            m_pending.insert(dir.absoluteFilePath(name));
        if (!qmls.isEmpty())
            qInfo().noquote() << "[live] 目录变更:" << QDir::toNativeSeparators(path);
        scheduleReload();
    });
}

void QmlLiveReload::watch(const QString &rootDir)
{
    m_rootDir = QDir(rootDir).absolutePath();
    refreshWatches();
    qInfo().noquote() << "[live] 已启动热重载，监视:" << QDir::toNativeSeparators(m_rootDir)
                      << " 文件" << m_watcher->files().size()
                      << "目录" << m_watcher->directories().size();
}

bool QmlLiveReload::isExcludedPath(const QString &path)
{
    const QString native = QDir::fromNativeSeparators(path);
    static const QStringList excluded = {
        QStringLiteral("/release/"),
        QStringLiteral("/debug/"),
        QStringLiteral("/.git/"),
        QStringLiteral("/build/"),
        QStringLiteral("/qmlcache/"),
    };
    for (const QString &needle : excluded)
    {
        if (native.contains(needle, Qt::CaseInsensitive))
            return true;
    }
    return false;
}

void QmlLiveReload::refreshWatches()
{
    // 只关心真正参与运行的 QML：main.qml 与 ui/ 下所有文件
    QSet<QString> wantFiles;
    QSet<QString> wantDirs;

    const QString entryPath = m_entryUrl.toLocalFile();
    if (!entryPath.isEmpty())
    {
        wantFiles.insert(entryPath);
        wantDirs.insert(QFileInfo(entryPath).absolutePath());
    }

    QDirIterator it(m_rootDir, QStringList() << QStringLiteral("*.qml"),
                    QDir::Files, QDirIterator::Subdirectories);
    while (it.hasNext())
    {
        const QString path = it.next();
        if (isExcludedPath(path))
            continue;
        wantFiles.insert(path);
        wantDirs.insert(QFileInfo(path).absolutePath());
    }

    // 增量同步：增删路径，避免把已有的 watch 拆掉重建
    const QStringList curFiles = m_watcher->files();
    for (const QString &path : wantFiles)
    {
        if (!curFiles.contains(path))
            m_watcher->addPath(path);
    }
    const QStringList curDirs = m_watcher->directories();
    for (const QString &path : wantDirs)
    {
        if (!curDirs.contains(path))
            m_watcher->addPath(path);
    }
}

void QmlLiveReload::scheduleReload()
{
    m_debounce->start();
}

void QmlLiveReload::performReload()
{
    if (m_busy)
        return;
    m_busy = true;

    // ① 只探测本次改动的文件：写错语法时保留旧窗口，别让人对着白屏查错。
    //    用独立的临时引擎，避免命中主引擎的组件缓存而读到旧内容。
    QQmlEngine probeEngine;
    probeEngine.setImportPathList(m_engine->importPathList());
    QSet<QString> probeSet = m_pending;
    probeSet.insert(m_entryUrl.toLocalFile());
    qInfo().noquote() << "[live] 语法探测:" << probeSet.size() << "个文件";
    for (const QString &path : probeSet)
    {
        if (path.isEmpty() || !QFile::exists(path))
            continue;
        // 用 setData 直接喂文件内容：绕过任何按 URL 的缓存，且同步编译
        QFile source(path);
        if (!source.open(QIODevice::ReadOnly))
            continue;
        const QByteArray sourceData = source.readAll();
        source.close();

        QQmlComponent probe(&probeEngine);
        probe.setData(sourceData, QUrl::fromLocalFile(path));
        if (probe.isError())
        {
            for (const QQmlError &error : probe.errors())
                qWarning().noquote() << "[live] 语法错误:" << error.toString();
            qWarning().noquote() << "[live] 本次改动未生效，旧界面保留:"
                                 << QDir::toNativeSeparators(path);
            m_pending.clear();
            m_busy = false;
            emit reloadFinished(false);
            return;
        }
    }
    m_pending.clear();

    // ② 销毁旧根对象并清缓存
    const QList<QObject *> roots = m_engine->rootObjects();
    for (QObject *root : roots)
        delete root;
    m_engine->clearComponentCache();

    // ③ 重新加载
    m_engine->load(m_entryUrl);
    const bool ok = !m_engine->rootObjects().isEmpty();
    if (ok)
        qInfo().noquote() << "[live] 重载完成";
    else
        qWarning().noquote() << "[live] 重载失败，请检查 QML 错误";

    // 编辑器保存后旧 watch 可能失效，重新对齐一次
    refreshWatches();

    m_busy = false;
    emit reloadFinished(ok);
}
