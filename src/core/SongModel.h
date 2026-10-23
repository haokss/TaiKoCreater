#ifndef SONGMODEL_H
#define SONGMODEL_H

#include <QAbstractListModel>
#include <QStringList>
#include <QList>
#include <QThread>
#include "SongInfo.h"
#include "ChartData.h"
#include "TjaValidator.h"

class SongScanner;

class SongModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(QStringList genres READ genres NOTIFY genresChanged)
    Q_PROPERTY(QStringList courses READ courses NOTIFY coursesChanged)
    Q_PROPERTY(QString currentRoot READ currentRoot NOTIFY currentRootChanged)
    Q_PROPERTY(int pageSize READ pageSize WRITE setPageSize NOTIFY pageSizeChanged)
    Q_PROPERTY(int currentPage READ currentPage NOTIFY currentPageChanged)
    Q_PROPERTY(int totalPages READ totalPages NOTIFY totalPagesChanged)
    Q_PROPERTY(int totalCount READ totalCount NOTIFY totalCountChanged)

public:
    enum Roles
    {
        TitleRole = Qt::UserRole + 1,
        SubtitleRole,
        GenreRole,
        GenreTitleRole,
        MaxLevelRole,
        BpmRole,
        DurationRole,
        FilePathRole,
        CoursesRole
    };

    explicit SongModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    void setSongs(const QList<SongInfo> &songs, const QString &songsRoot);
    Q_INVOKABLE QList<SongInfo> songs() const;
    QStringList genres() const;
    QStringList courses() const;
    QString currentRoot() const;

    // 异步设置根目录（在后台线程扫描，完成后发出 songsLoaded 信号）
    Q_INVOKABLE void setRootPathAsync(const QString &gameRoot);

    // 同步版本（保留兼容，但会阻塞调用线程）
    Q_INVOKABLE bool setRootPath(const QString &gameRoot);

    // minLevel: 最低难度, maxLevel: 最高难度（0 表示不限）
    Q_INVOKABLE void applyFilter(int minLevel, int maxLevel, const QString &genre, const QString &course = "");
    Q_INVOKABLE void applySort(const QString &field, bool ascending = true);
    Q_INVOKABLE void restoreDefaults();

    // 获取某首歌指定 COURSE 的铺面数据（返回 QVariantMap）
    Q_INVOKABLE QVariantMap getChartData(int rowIndex, const QString &courseName);

    Q_INVOKABLE bool exportFilteredToFolder();
    Q_INVOKABLE bool removeExportedFolder();
    Q_INVOKABLE void restartGame();

    // 解析 TJA 文本字符串（来自 AI 生成），返回 ChartView 的 map 形式供 SongDetail 显示
    Q_INVOKABLE QVariantMap parseGeneratedTJA(const QString &tjaContent);

    // 校验任意 TJA 文本，返回 ChartView 字段 + problems 列表
    Q_INVOKABLE QVariantMap validateTJA(const QString &tjaContent);

    // 校验磁盘上的 TJA 文件（自动识别编码）
    Q_INVOKABLE QVariantMap validateTJAFile(const QString &filePath);

    // 最近一次解析/校验的问题列表与人类可读报告
    Q_INVOKABLE QVariantList lastValidationProblems() const;
    Q_INVOKABLE QString lastValidationReport() const;

    // 保存 AI 生成的 TJA 文本到指定路径，返回是否成功
    Q_INVOKABLE bool saveGeneratedTJA(const QString &directory, const QString &fileName);

    // 分页
    int pageSize() const { return m_pageSize; }
    void setPageSize(int size);
    int currentPage() const { return m_currentPage; }
    int totalPages() const;
    int totalCount() const { return m_filteredSongs.count(); }
    Q_INVOKABLE void goToPage(int page);
    Q_INVOKABLE void nextPage();
    Q_INVOKABLE void prevPage();

    // 返回最近一次 AI 生成的 TJA 文本（用于 QML 端保存）
    Q_INVOKABLE QString lastGeneratedTJA() const { return m_generatedTJA; }

    // 从磁盘文件加载并解析 TJA 谱面
    Q_INVOKABLE QVariantMap loadTJAFile(const QString &filePath);

signals:
    void pageSizeChanged();
    void currentPageChanged();
    void totalPagesChanged();
    void totalCountChanged();
    void countChanged();
    void genresChanged();
    void coursesChanged();
    void currentRootChanged();
    /// 异步扫描完成信号
    void songsLoaded(int songCount);
    /// 异步扫描出错信号
    void scanError(const QString &errorMessage);

private:
    QList<SongInfo> m_allSongs;
    QList<SongInfo> m_filteredSongs;
    QStringList m_genres;
    QStringList m_courses;
    QString m_songsRoot;
    QString m_gameRoot;
    SongScanner *m_scanner = nullptr;
    QString m_generatedTJA; // 最近一次 AI 生成的 TJA 内容
    ChartView m_lastChart;  // 最近一次解析/校验的谱面
    QList<TjaProblem> m_lastProblems; // 最近一次校验的问题列表
    int m_pageSize = 50;
    int m_currentPage = 0;

    void rebuildGenres();
    void rebuildCourses();
};

#endif // SONGMODEL_H