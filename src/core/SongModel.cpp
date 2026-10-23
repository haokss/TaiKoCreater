#include "SongModel.h"
#include "SongScanner.h"
#include "../utils/Logger.h"
#include "../utils/ThreadPool.h"
#include "../utils/ToastManager.h"
#include <algorithm>
#include <QSet>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QProcess>
#include <QThread>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>
#include <QTextStream>

SongModel::SongModel(QObject *parent) : QAbstractListModel(parent) {}

int SongModel::rowCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent)
    int start = m_currentPage * m_pageSize;
    int total = m_filteredSongs.count();
    if (start >= total) return 0;
    return qMin(m_pageSize, total - start);
}

QVariant SongModel::data(const QModelIndex &index, int role) const
{
    int realIdx = m_currentPage * m_pageSize + index.row();
    if (!index.isValid() || realIdx < 0 || realIdx >= m_filteredSongs.count())
        return QVariant();
    const SongInfo &song = m_filteredSongs.at(realIdx);
    switch (role)
    {
    case TitleRole:
        return song.title;
    case SubtitleRole:
        return song.subtitle;
    case GenreRole:
        return song.genre;
    case GenreTitleRole:
        return song.genreTitle;
    case MaxLevelRole:
        return song.maxLevel;
    case BpmRole:
        return song.bpm;
    case DurationRole:
        return song.estimatedDurationSec;
    case FilePathRole:
        return song.filePath;
    case CoursesRole:
    {
        QVariantList list;
        for (const CourseInfo &c : song.courses)
        {
            QVariantMap m;
            m["course"] = c.course;
            m["level"] = c.level;
            m["noteCount"] = c.noteCount;
            list.append(m);
        }
        return list;
    }
    default:
        return QVariant();
    }
}

QHash<int, QByteArray> SongModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[TitleRole] = "title";
    roles[SubtitleRole] = "subtitle";
    roles[GenreRole] = "genre";
    roles[GenreTitleRole] = "genreTitle";
    roles[MaxLevelRole] = "maxLevel";
    roles[BpmRole] = "bpm";
    roles[DurationRole] = "duration";
    roles[FilePathRole] = "filePath";
    roles[CoursesRole] = "courses";
    return roles;
}

void SongModel::setSongs(const QList<SongInfo> &songs, const QString &songsRoot)
{
    LOG_TAG("Model", "setSongs: " + QString::number(songs.size()) + " 首");
    beginResetModel();
    m_allSongs = songs;
    m_filteredSongs = songs;
    m_songsRoot = songsRoot;
    m_currentPage = 0;
    if (!songsRoot.isEmpty())
    {
        QDir dir(songsRoot);
        if (dir.exists())
        {
            dir.cdUp();
            m_gameRoot = dir.absolutePath();
        }
        else
        {
            m_gameRoot = songsRoot;
        }
    }
    else
    {
        m_gameRoot.clear();
    }
    endResetModel();
    rebuildGenres();
    rebuildCourses();
    emit countChanged();
    emit currentPageChanged();
    emit totalPagesChanged();
    emit totalCountChanged();
}

QList<SongInfo> SongModel::songs() const { return m_filteredSongs; }
QStringList SongModel::genres() const { return m_genres; }
QStringList SongModel::courses() const { return m_courses; }
QString SongModel::currentRoot() const { return m_gameRoot; }

bool SongModel::setRootPath(const QString &gameRoot)
{
    LOG_TAG("Model", "setRootPath (sync): " + gameRoot);
    QString tryPath = gameRoot;
    if (!tryPath.endsWith("/Songs", Qt::CaseInsensitive) && !tryPath.endsWith("\\Songs", Qt::CaseInsensitive))
        tryPath = gameRoot + "/Songs";
    QDir dir(tryPath);
    if (!dir.exists())
    {
        tryPath = gameRoot + "/Songs";
        dir.setPath(tryPath);
        if (!dir.exists())
        {
            dir.setPath(gameRoot);
            bool found = false;
            const auto entries = dir.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
            for (const QFileInfo &entry : entries)
                if (QFile::exists(entry.absoluteFilePath() + "/box.def"))
                {
                    found = true;
                    break;
                }
            if (!found)
            {
                LOG_TAG("Model", "未找到有效的 Songs 目录");
                return false;
            }
            tryPath = gameRoot;
        }
    }
    QString songsRoot = tryPath;
    SongScanner scanner;
    QList<SongInfo> newSongs = scanner.scanFolder(songsRoot);
    beginResetModel();
    m_allSongs = newSongs;
    m_filteredSongs = newSongs;
    m_songsRoot = songsRoot;
    m_gameRoot = gameRoot;
    m_currentPage = 0;
    endResetModel();
    rebuildGenres();
    rebuildCourses();
    emit countChanged();
    emit currentRootChanged();
    emit songsLoaded(newSongs.size());
    emit currentPageChanged();
    emit totalPagesChanged();
    emit totalCountChanged();
    return true;
}

void SongModel::setRootPathAsync(const QString &gameRoot)
{
    LOG_TAG("Model", "setRootPathAsync: " + gameRoot);

    // 先确定 songsRoot 路径（在主线程做，避免线程间数据竞争）
    QString tryPath = gameRoot;
    if (!tryPath.endsWith("/Songs", Qt::CaseInsensitive) && !tryPath.endsWith("\\Songs", Qt::CaseInsensitive))
        tryPath = gameRoot + "/Songs";
    QDir dir(tryPath);
    if (!dir.exists())
    {
        dir.setPath(tryPath);
        if (!dir.exists())
        {
            dir.setPath(gameRoot);
            bool found = false;
            const auto entries = dir.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
            for (const QFileInfo &entry : entries)
                if (QFile::exists(entry.absoluteFilePath() + "/box.def"))
                {
                    found = true;
                    break;
                }
            if (!found)
            {
                LOG_TAG("Model", "未找到有效的 Songs 目录");
                TOAST_ERROR("未找到有效的 Songs 目录");
                emit scanError("未找到有效的 Songs 目录: " + gameRoot);
                return;
            }
            tryPath = gameRoot;
        }
    }

    const QString songsRoot = tryPath;
    const QString root = gameRoot;

    // 在后台线程执行扫描
    ThreadPool::instance()->enqueue([this, songsRoot, root]() {
        LOG_TAG("Model", "后台线程开始扫描...");
        SongScanner scanner;
        QList<SongInfo> newSongs = scanner.scanFolder(songsRoot);
        LOG_TAG("Model", "后台线程扫描完成，" + QString::number(newSongs.size()) + " 首歌曲");

        // 回到主线程更新模型
        ThreadPool::instance()->invokeOnObject(this, [this, songs = std::move(newSongs), songsRoot, root]() {
            beginResetModel();
            m_allSongs = songs;
            m_filteredSongs = songs;
            m_songsRoot = songsRoot;
            m_gameRoot = root;
            m_currentPage = 0;
            endResetModel();
            rebuildGenres();
            rebuildCourses();
            emit countChanged();
            emit currentRootChanged();
            emit songsLoaded(songs.size());
            emit currentPageChanged();
            emit totalPagesChanged();
            emit totalCountChanged();
            TOAST_SUCCESS("已加载 " + QString::number(songs.size()) + " 首歌曲");
            LOG_TAG("Model", "UI 更新完成，" + QString::number(songs.size()) + " 首歌曲已就绪");
        });
    });
}

void SongModel::rebuildCourses()
{
    QSet<QString> courseSet;
    courseSet.insert("全部");
    for (const SongInfo &s : m_allSongs)
        for (const CourseInfo &c : s.courses)
            if (!c.course.isEmpty())
                courseSet.insert(c.course);
    QStringList sorted = courseSet.values();
    std::sort(sorted.begin(), sorted.end());
    if (m_courses != sorted)
    {
        m_courses = sorted;
        emit coursesChanged();
    }
}

void SongModel::rebuildGenres()
{
    QSet<QString> genreSet;
    genreSet.insert("全部");
    for (const SongInfo &s : m_allSongs)
    {
        QString g = s.genreTitle;
        if (g.isEmpty())
            g = s.genre;
        if (!g.isEmpty())
            genreSet.insert(g);
    }
    QStringList sorted = genreSet.values();
    std::sort(sorted.begin(), sorted.end());
    if (m_genres != sorted)
    {
        m_genres = sorted;
        emit genresChanged();
    }
}

void SongModel::applyFilter(int minLevel, int maxLevel, const QString &genre, const QString &course)
{
    LOG_TAG("Model", "applyFilter: minLv=" + QString::number(minLevel) + " maxLv=" + QString::number(maxLevel) + " genre=" + genre + " course=" + course + " total=" + QString::number(m_allSongs.size()));
    m_currentPage = 0;
    beginResetModel();
    m_filteredSongs.clear();
    for (const SongInfo &s : m_allSongs)
    {
        if (minLevel > 0 && s.maxLevel < minLevel)
            continue;
        if (maxLevel > 0 && s.maxLevel > maxLevel)
            continue;
        if (!genre.isEmpty() && genre != "全部" && s.genre != genre && s.genreTitle != genre)
            continue;
        if (!course.isEmpty() && course != "全部")
        {
            bool has = false;
            QString fc = course.toLower().trimmed();
            for (const CourseInfo &c : s.courses)
            {
                if (c.course.toLower().trimmed() == fc)
                {
                    has = true;
                    break;
                }
            }
            if (!has)
                continue;
        }
        m_filteredSongs.append(s);
    }
    endResetModel();
    emit countChanged();
    emit currentPageChanged();
    emit totalPagesChanged();
    emit totalCountChanged();
}

void SongModel::applySort(const QString &field, bool ascending)
{
    LOG_TAG("Model", "applySort: field=" + field + " asc=" + (ascending ? "true" : "false") + " filtered=" + QString::number(m_filteredSongs.size()));
    m_currentPage = 0;
    beginResetModel();
    std::sort(m_filteredSongs.begin(), m_filteredSongs.end(),
              [&](const SongInfo &a, const SongInfo &b)
              {
                  int c = 0;
                  if (field == "title")
                      c = QString::localeAwareCompare(a.title, b.title);
                  else if (field == "genreTitle")
                      c = QString::localeAwareCompare(a.genreTitle, b.genreTitle);
                  else if (field == "maxLevel")
                      c = a.maxLevel - b.maxLevel;
                  else if (field == "duration")
                      c = (a.estimatedDurationSec < b.estimatedDurationSec) ? -1 : (a.estimatedDurationSec > b.estimatedDurationSec) ? 1
                                                                                                                                     : 0;
                  return ascending ? (c < 0) : (c > 0);
              });
    endResetModel();
    emit countChanged();
    emit currentPageChanged();
    emit totalPagesChanged();
    emit totalCountChanged();
}

void SongModel::restoreDefaults()
{
    m_currentPage = 0;
    beginResetModel();
    m_filteredSongs = m_allSongs;
    endResetModel();
    emit countChanged();
    emit currentPageChanged();
    emit totalPagesChanged();
    emit totalCountChanged();
}

bool SongModel::exportFilteredToFolder()
{
    if (m_filteredSongs.isEmpty() || m_songsRoot.isEmpty())
        return false;
    QString destDir = m_songsRoot + "/筛选歌曲";
    QDir dir(destDir);
    if (dir.exists())
        dir.removeRecursively();
    if (!dir.mkpath(destDir))
        return false;
    for (const SongInfo &song : m_filteredSongs)
    {
        QFileInfo tjaInfo(song.filePath);
        QString sn = tjaInfo.completeBaseName();
        QString srcDir = tjaInfo.absolutePath();
        QFile::copy(song.filePath, destDir + "/" + tjaInfo.fileName());
        if (QFile::exists(srcDir + "/" + sn + ".ogg"))
            QFile::copy(srcDir + "/" + sn + ".ogg", destDir + "/" + sn + ".ogg");
        if (QFile::exists(srcDir + "/" + sn + ".tja.score.ini"))
            QFile::copy(srcDir + "/" + sn + ".tja.score.ini", destDir + "/" + sn + ".tja.score.ini");
    }
    return true;
}

bool SongModel::removeExportedFolder()
{
    if (m_songsRoot.isEmpty())
        return false;
    QString destDir = m_songsRoot + "/筛选歌曲";
    QDir dir(destDir);
    if (!dir.exists())
        return false;
    return dir.removeRecursively();
}

QVariantMap SongModel::getChartData(int rowIndex, const QString &courseName)
{
    QVariantMap result;
    if (rowIndex < 0 || rowIndex >= m_filteredSongs.count())
    {
        LOG_TAG("Model", "getChartData: rowIndex=" + QString::number(rowIndex) + " 越界, filtered=" + QString::number(m_filteredSongs.count()));
        return result;
    }
    const SongInfo &song = m_filteredSongs.at(rowIndex);
    LOG_TAG("Model", "getChartData: row=" + QString::number(rowIndex) + " title=" + song.title + " course=" + courseName + " path=" + song.filePath);
    CourseChart chart = SongScanner::parseCourseChart(song.filePath, courseName);
    LOG_TAG("Model", "getChartData done: course=" + chart.course + " level=" + QString::number(chart.level) + " notes=" + QString::number(chart.totalNotes) + " measures=" + QString::number(chart.measureLines.size()));
    // 统一走 ChartView：字段名由 Q_PROPERTY 决定，QVariantMap 由元对象自动导出
    const ChartView view = ChartView::fromChart(chart);
    return view.toVariantMap();
}

QVariantMap SongModel::parseGeneratedTJA(const QString &tjaContent)
{
    if (tjaContent.isEmpty())
        return QVariantMap();

    // 保存原始 TJA 文本，供 saveGeneratedTJA 使用
    m_generatedTJA = tjaContent;

    // 解析与校验走同一条路径，避免"解析器"和"校验器"两套规则漂移
    QList<TjaProblem> problems;
    m_lastChart = TjaValidator::validateText(tjaContent, &problems);
    m_lastProblems = problems;

    LOG_TAG("Model", "parseGeneratedTJA: " + m_lastChart.course
                         + " ★" + QString::number(m_lastChart.level)
                         + " BPM " + QString::number(m_lastChart.bpm)
                         + " 小节 " + QString::number(m_lastChart.measureCount)
                         + " 音符 " + QString::number(m_lastChart.totalNotes)
                         + " | 错误 " + QString::number(m_lastChart.errorCount)
                         + " 警告 " + QString::number(m_lastChart.warningCount));

    for (const TjaProblem &p : problems)
    {
        if (p.severity == TjaProblem::Info)
            continue;
        LOG_TAG("TJA", p.severityText() + " " + p.code + ": " + p.message
                          + (p.line > 0 ? " (第 " + QString::number(p.line) + " 行)" : QString()));
    }

    QVariantMap result = m_lastChart.toVariantMap();
    result.insert("problems", TjaValidator::toVariantList(problems));
    return result;
}

QVariantMap SongModel::validateTJA(const QString &tjaContent)
{
    QList<TjaProblem> problems;
    const ChartView view = TjaValidator::validateText(tjaContent, &problems);
    QVariantMap result = view.toVariantMap();
    result.insert("problems", TjaValidator::toVariantList(problems));
    return result;
}

QVariantMap SongModel::validateTJAFile(const QString &filePath)
{
    // Qt6 FileDialog 返回 file:/// 前缀的 URL，转为本地路径
    QString localPath = filePath;
    if (localPath.startsWith("file:///"))
        localPath = QUrl(localPath).toLocalFile();

    QList<TjaProblem> problems;
    const ChartView view = TjaValidator::validateFile(localPath, &problems);

    m_lastChart = view;
    m_lastProblems = problems;

    LOG_TAG("Model", "validateTJAFile: " + localPath
                         + " | 错误 " + QString::number(view.errorCount)
                         + " 警告 " + QString::number(view.warningCount));

    QVariantMap result = view.toVariantMap();
    result.insert("filePath", localPath);
    result.insert("problems", TjaValidator::toVariantList(problems));
    result.insert("report", TjaValidator::reportText(view, problems));
    return result;
}

QVariantList SongModel::lastValidationProblems() const
{
    return TjaValidator::toVariantList(m_lastProblems);
}

QString SongModel::lastValidationReport() const
{
    return TjaValidator::reportText(m_lastChart, m_lastProblems);
}

bool SongModel::saveGeneratedTJA(const QString &directory, const QString &fileName)
{
    if (m_generatedTJA.isEmpty())
    {
        LOG_TAG("Model", "saveGeneratedTJA: 没有已生成的内容");
        return false;
    }

    QDir dir(directory);
    if (!dir.exists())
    {
        if (!dir.mkpath(directory))
        {
            LOG_TAG("Model", "saveGeneratedTJA: 无法创建目录 " + directory);
            return false;
        }
    }

    QString safeName = fileName;
    // 移除文件名中的非法字符
    safeName.replace('/', '_').replace('\\', '_').replace(':', '_').replace('*', '_').replace('?', '_').replace('"', '_').replace('<', '_').replace('>', '_').replace('|', '_');

    QString filePath = dir.absoluteFilePath(safeName);
    if (!filePath.endsWith(".tja", Qt::CaseInsensitive))
        filePath += ".tja";

    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text))
    {
        LOG_TAG("Model", "saveGeneratedTJA: 无法写入文件 " + filePath);
        return false;
    }

    QTextStream out(&file);
    out << m_generatedTJA;
    file.close();

    LOG_TAG("Model", "saveGeneratedTJA: 已保存到 " + filePath);
    return true;
}

void SongModel::restartGame()
{
    if (m_gameRoot.isEmpty())
        return;
    QDir rootDir(m_gameRoot);
    const auto files = rootDir.entryInfoList(QStringList() << "*.exe", QDir::Files, QDir::Name);
    QString exePath;
    for (const QFileInfo &fi : files)
    {
        QString n = fi.fileName();
        if (n.contains("taiko", Qt::CaseInsensitive) || n.contains("donda", Qt::CaseInsensitive))
        {
            exePath = fi.absoluteFilePath();
            break;
        }
    }
    if (exePath.isEmpty() && !files.isEmpty())
        exePath = files.first().absoluteFilePath();
    if (exePath.isEmpty())
    {
        LOG_TAG("Model", "未找到游戏 exe");
        return;
    }
    QString pn = QFileInfo(exePath).completeBaseName();
    QProcess::execute("taskkill", QStringList() << "/f" << "/im" << (pn + ".exe"));
    QThread::msleep(500);
    QProcess::startDetached(exePath, QStringList(), QFileInfo(exePath).absolutePath());
}

QVariantMap SongModel::loadTJAFile(const QString &filePath)
{
    // Qt6 FileDialog 返回 file:/// 前缀的 URL，转为本地路径
    QString localPath = filePath;
    if (localPath.startsWith("file:///"))
        localPath = QUrl(localPath).toLocalFile();

    QFile file(localPath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
    {
        LOG_TAG("Model", "loadTJAFile: 无法打开文件 " + localPath);
        emit scanError("无法打开TJA文件: " + localPath);
        return QVariantMap();
    }
    QTextStream in(&file);
    QString content = in.readAll();
    file.close();
    LOG_TAG("Model", "loadTJAFile: 已读取 " + localPath + " (" + QString::number(content.length()) + " 字符)");
    return parseGeneratedTJA(content);
}

// ═══════════════════════════════════════════
// 分页方法实现
// ═══════════════════════════════════════════

void SongModel::setPageSize(int size)
{
    if (size < 10) size = 10;
    if (size > 500) size = 500;
    if (m_pageSize == size) return;
    m_pageSize = size;
    m_currentPage = 0;
    beginResetModel();
    endResetModel();
    emit pageSizeChanged();
    emit countChanged();
    emit currentPageChanged();
    emit totalPagesChanged();
}

int SongModel::totalPages() const
{
    if (m_filteredSongs.isEmpty()) return 0;
    return (m_filteredSongs.count() + m_pageSize - 1) / m_pageSize;
}

void SongModel::goToPage(int page)
{
    int tp = totalPages();
    if (tp == 0) return;
    int newPage = qMax(0, qMin(page, tp - 1));
    if (newPage == m_currentPage) return;
    m_currentPage = newPage;
    beginResetModel();
    endResetModel();
    emit countChanged();
    emit currentPageChanged();
}

void SongModel::nextPage()
{
    goToPage(m_currentPage + 1);
}

void SongModel::prevPage()
{
    goToPage(m_currentPage - 1);
}