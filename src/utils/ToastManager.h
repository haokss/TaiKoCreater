#ifndef TOASTMANAGER_H
#define TOASTMANAGER_H

#include <QObject>
#include <QString>
#include <QMutex>

/// Toast 弹框类型
namespace ToastType {
    Q_NAMESPACE
    enum Type {
        Info = 0,
        Success = 1,
        Warning = 2,
        Error = 3
    };
    Q_ENUM_NS(Type)
}

/// Toast 消息数据
struct ToastMessage {
    Q_GADGET
public:
    Q_PROPERTY(int type MEMBER type)
    Q_PROPERTY(QString message MEMBER message)
    Q_PROPERTY(int durationMs MEMBER durationMs)

public:
    int type = ToastType::Info;
    QString message;
    int durationMs = 3000; // 默认 3 秒
};

/// Toast 管理器（单例），供 C++ / QML 统一调用
class ToastManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int type READ type NOTIFY toastRequested)
    Q_PROPERTY(QString message READ message NOTIFY toastRequested)
    Q_PROPERTY(int durationMs READ durationMs NOTIFY toastRequested)

public:
    static ToastManager* instance();

    /// 显示一个 Toast
    /// @param type     类型: 0=Info, 1=Success, 2=Warning, 3=Error
    /// @param message  显示内容
    /// @param durationMs 显示时长（毫秒），0 表示使用默认值 3000ms
    Q_INVOKABLE void show(int type, const QString &message, int durationMs = 0);

    // 便捷方法
    Q_INVOKABLE void info(const QString &message, int durationMs = 0);
    Q_INVOKABLE void success(const QString &message, int durationMs = 0);
    Q_INVOKABLE void warning(const QString &message, int durationMs = 0);
    Q_INVOKABLE void error(const QString &message, int durationMs = 0);

    int type() const { return m_current.type; }
    QString message() const { return m_current.message; }
    int durationMs() const { return m_current.durationMs; }

signals:
    /// QML 监听此信号来显示弹框
    void toastRequested();

private:
    explicit ToastManager(QObject *parent = nullptr);
    static ToastManager *s_instance;
    ToastMessage m_current;
    mutable QMutex m_mutex;
};

// 便捷宏
#define TOAST_INFO(msg)       ToastManager::instance()->info(msg)
#define TOAST_SUCCESS(msg)    ToastManager::instance()->success(msg)
#define TOAST_WARNING(msg)    ToastManager::instance()->warning(msg)
#define TOAST_ERROR(msg)      ToastManager::instance()->error(msg)

#endif // TOASTMANAGER_H