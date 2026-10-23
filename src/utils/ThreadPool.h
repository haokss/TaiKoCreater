#ifndef THREADPOOL_H
#define THREADPOOL_H

#include <QObject>
#include <QThreadPool>
#include <QRunnable>
#include <functional>
#include <atomic>

/// 基于 std::function 的 Runnable 包装器
class FunctionRunnable : public QRunnable
{
public:
    explicit FunctionRunnable(std::function<void()> task)
        : m_task(std::move(task)) {}

    void run() override
    {
        if (m_task) {
            m_task();
        }
    }

private:
    std::function<void()> m_task;
};

/// 线程池工具类（单例），基于 QThreadPool 封装
class ThreadPool : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int maxThreadCount READ maxThreadCount WRITE setMaxThreadCount)
    Q_PROPERTY(int activeThreadCount READ activeThreadCount)

public:
    static ThreadPool* instance();

    /// 获取最大线程数
    int maxThreadCount() const;

    /// 设置最大线程数
    void setMaxThreadCount(int count);

    /// 当前活跃线程数
    int activeThreadCount() const;

    /// 投递一个无参任务（lambda / std::function）
    /// @param task        要执行的任务
    /// @param priority    优先级，0 为默认（值越大优先级越高）
    void enqueue(std::function<void()> task, int priority = 0);

    /// 投递任务到指定 receiver 的事件循环线程执行（线程安全跨线程调用）
    /// 相当于 QMetaObject::invokeMethod(receiver, method, Qt::QueuedConnection)
    template <typename Func>
    void invokeOnObject(QObject *receiver, Func &&slot)
    {
        QMetaObject::invokeMethod(receiver, std::forward<Func>(slot), Qt::QueuedConnection);
    }

    /// 等待所有已提交任务执行完成
    void waitForDone();

    /// 清空等待队列中尚未开始的任务（正在执行的不受影响）
    void clear();

    /// 获取待处理任务数（近似值）
    int pendingCount() const;

signals:
    /// 单个任务完成时触发（在工作线程中发射，可用于 UI 更新）
    void taskFinished();

    /// 所有任务完成时触发
    void allTasksFinished();

private:
    explicit ThreadPool(QObject *parent = nullptr);
    ~ThreadPool() override;

    static ThreadPool *s_instance;
    QThreadPool *m_pool;
    std::atomic<int> m_pendingCount{0};

    void onTaskFinished();
};

// 便捷宏
#define THREAD_POOL ThreadPool::instance()

#endif // THREADPOOL_H