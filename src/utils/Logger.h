#ifndef LOGGER_H
#define LOGGER_H

#include <QObject>
#include <QStringList>
#include <QDateTime>
#include <QMutex>

class Logger : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QStringList logs READ logs NOTIFY logsChanged)
public:
    Q_INVOKABLE void addLog(const QString& msg);
    static Logger* instance();

    QStringList logs() const;

    // 供 C++ 代码调用
    static void log(const QString &message);
    static void log(const QString &tag, const QString &message);

    Q_INVOKABLE void clear();

signals:
    void logsChanged();

private:
    explicit Logger(QObject *parent = nullptr);
    static Logger *s_instance;
    QStringList m_logs;
    mutable QMutex m_mutex;
};

// 便捷宏
#define LOG(msg) Logger::log(__FUNCTION__, msg)
#define LOG_TAG(tag, msg) Logger::log(tag, msg)

#endif // LOGGER_H