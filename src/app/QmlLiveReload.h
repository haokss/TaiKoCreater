#ifndef QMLLIVERELOAD_H
#define QMLLIVERELOAD_H

#include <QObject>
#include <QSet>
#include <QString>
#include <QUrl>

class QQmlApplicationEngine;
class QFileSystemWatcher;
class QTimer;

// ═══════════════════════════════════════════════════════════════════
// QmlLiveReload —— 开发模式下的 QML 热重载
//
// 监视源码目录里的 *.qml，存盘后自动清缓存、销毁旧根对象、重新 load，
// 不用重新编译 C++。只监听含 .qml 的目录与文件，跳过 release/ debug/ 等。
//
// 重载前会先用 QQmlComponent 做一次语法探测：新代码有语法错误时保留旧窗口，
// 把错误打到控制台，避免"存盘存错 → 窗口直接消失"。
// ═══════════════════════════════════════════════════════════════════
class QmlLiveReload : public QObject
{
    Q_OBJECT
public:
    explicit QmlLiveReload(QQmlApplicationEngine *engine, const QUrl &entryUrl,
                           QObject *parent = nullptr);

    // 开始监视（rootDir 一般就是 main.qml 所在目录）
    void watch(const QString &rootDir);

signals:
    void reloadFinished(bool ok);

private:
    void scheduleReload();
    void performReload();
    void refreshWatches();
    static bool isExcludedPath(const QString &path);

    QQmlApplicationEngine *m_engine = nullptr;
    QUrl m_entryUrl;
    QFileSystemWatcher *m_watcher = nullptr;
    QTimer *m_debounce = nullptr;
    QString m_rootDir;
    QSet<QString> m_pending; // 本次待重载的变更文件，用来做语法探测
    bool m_busy = false;
};

#endif // QMLLIVERELOAD_H
