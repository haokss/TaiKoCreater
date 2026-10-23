#include "ThreadPool.h"
#include "Logger.h"

ThreadPool *ThreadPool::s_instance = nullptr;

ThreadPool *ThreadPool::instance()
{
    if (!s_instance)
    {
        s_instance = new ThreadPool();
    }
    return s_instance;
}

ThreadPool::ThreadPool(QObject *parent)
    : QObject(parent), m_pool(new QThreadPool(this)), m_pendingCount(0)
{
    // 默认线程数为 CPU 核心数
    m_pool->setMaxThreadCount(QThreadPool::globalInstance()->maxThreadCount());
}

ThreadPool::~ThreadPool()
{
    waitForDone();
}

int ThreadPool::maxThreadCount() const
{
    return m_pool->maxThreadCount();
}

void ThreadPool::setMaxThreadCount(int count)
{
    if (count > 0)
    {
        m_pool->setMaxThreadCount(count);
    }
}

int ThreadPool::activeThreadCount() const
{
    return m_pool->activeThreadCount();
}

void ThreadPool::enqueue(std::function<void()> task, int priority)
{
    if (!task)
        return;

    m_pendingCount.fetch_add(1, std::memory_order_relaxed);

    auto *runnable = new FunctionRunnable([this, task = std::move(task)]()
                                          {
        // 执行任务
        task();

        // 单个任务完成信号
        emit taskFinished();

        onTaskFinished(); });

    runnable->setAutoDelete(true);
    m_pool->start(runnable, priority);
}

void ThreadPool::onTaskFinished()
{
    int prev = m_pendingCount.fetch_sub(1, std::memory_order_acq_rel);
    if (prev == 1)
    {
        // 最后一个任务完成
        emit allTasksFinished();
    }
}

void ThreadPool::waitForDone()
{
    m_pool->waitForDone();
}

void ThreadPool::clear()
{
    m_pool->clear();
    m_pendingCount.store(0, std::memory_order_release);
}

int ThreadPool::pendingCount() const
{
    return m_pendingCount.load(std::memory_order_acquire);
}