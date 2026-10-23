#include "Logger.h"

Logger *Logger::s_instance = nullptr;

Logger *Logger::instance()
{
    if (!s_instance)
    {
        s_instance = new Logger();
    }
    return s_instance;
}

Logger::Logger(QObject *parent) : QObject(parent) {}

QStringList Logger::logs() const
{
    QMutexLocker locker(&m_mutex);
    return m_logs;
}

void Logger::log(const QString &message)
{
    Logger *inst = instance();
    QMutexLocker locker(&inst->m_mutex);
    QString timestamp = QDateTime::currentDateTime().toString("hh:mm:ss.zzz");
    inst->m_logs.append("[" + timestamp + "] " + message);
    if (inst->m_logs.size() > 1000)
        inst->m_logs.removeFirst();
    locker.unlock();
    emit inst->logsChanged();
}

void Logger::log(const QString &tag, const QString &message)
{
    log("[" + tag + "] " + message);
}

void Logger::clear()
{
    QMutexLocker locker(&m_mutex);
    m_logs.clear();
    locker.unlock();
    emit logsChanged();
}

void Logger::addLog(const QString &msg)
{
    log(msg);
}