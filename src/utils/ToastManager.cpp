#include "ToastManager.h"
#include <QMutexLocker>

ToastManager* ToastManager::s_instance = nullptr;

ToastManager* ToastManager::instance()
{
    if (!s_instance) {
        s_instance = new ToastManager();
    }
    return s_instance;
}

ToastManager::ToastManager(QObject *parent)
    : QObject(parent)
{
}

void ToastManager::show(int type, const QString &message, int durationMs)
{
    if (message.isEmpty()) return;

    {
        QMutexLocker locker(&m_mutex);
        m_current.type = type;
        m_current.message = message;
        m_current.durationMs = (durationMs > 0) ? durationMs : 3000;
    }

    emit toastRequested();
}

void ToastManager::info(const QString &message, int durationMs)
{
    show(ToastType::Info, message, durationMs);
}

void ToastManager::success(const QString &message, int durationMs)
{
    show(ToastType::Success, message, durationMs);
}

void ToastManager::warning(const QString &message, int durationMs)
{
    show(ToastType::Warning, message, durationMs);
}

void ToastManager::error(const QString &message, int durationMs)
{
    show(ToastType::Error, message, durationMs);
}