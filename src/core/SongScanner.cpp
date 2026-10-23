#include "SongScanner.h"
#include "../utils/Logger.h"
#include <QDir>
#include <QFile>
#include <QTextStream>
#include <QRegularExpression>
#include <QFileInfoList>
#include <QDebug>
#include <QStringDecoder>

SongScanner::SongScanner(QObject *parent) : QObject(parent) {}

static QString decodeFileContent(const QByteArray &raw)
{
    if (raw.isEmpty())
        return QString();

    auto sjisDecoder = QStringDecoder("Shift-JIS");
    if (sjisDecoder.isValid())
    {
        QString sjisResult = sjisDecoder.decode(raw);
        if (!sjisResult.contains(QChar(0xFFFD)))
            return sjisResult;
    }
    auto utf8Decoder = QStringDecoder("UTF-8");
    if (utf8Decoder.isValid())
    {
        QString utf8Result = utf8Decoder.decode(raw);
        if (!utf8Result.contains(QChar(0xFFFD)))
            return utf8Result;
    }
    auto sysDecoder = QStringDecoder("System");
    if (sysDecoder.isValid())
    {
        QString sysResult = sysDecoder.decode(raw);
        if (!sysResult.contains(QChar(0xFFFD)))
            return sysResult;
    }
    if (sjisDecoder.isValid())
        return sjisDecoder.decode(raw);
    return QString::fromLatin1(raw);
}

static QString readFile(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return QString();
    QByteArray raw = file.readAll();
    file.close();
    return decodeFileContent(raw);
}

QList<SongInfo> SongScanner::scanFolder(const QString &rootPath)
{
    LOG_TAG("Scanner", "开始扫描目录: " + rootPath);
    QList<SongInfo> results;
    QDir rootDir(rootPath);
    if (!rootDir.exists())
    {
        LOG_TAG("Scanner", "目录不存在: " + rootPath);
        return results;
    }
    const auto subDirs = rootDir.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
    LOG_TAG("Scanner", "发现 " + QString::number(subDirs.size()) + " 个分类目录");
    for (const QFileInfo &dirInfo : subDirs)
    {
        QString genreName = dirInfo.fileName();
        QString boxDefPath = dirInfo.absoluteFilePath() + "/box.def";
        QString genreTag = genreName;
        QString genreTitle = genreName;
        QString boxContent = readFile(boxDefPath);
        for (const QString &line : boxContent.split('\n'))
        {
            QString t = line.trimmed();
            if (t.startsWith("#GENRE:"))
                genreTag = t.mid(7).trimmed();
            if (t.startsWith("#TITLE:"))
                genreTitle = t.mid(7).trimmed();
        }
        LOG_TAG("Scanner", "扫描分类: " + genreName + " -> " + genreTitle);
        scanGenreFolder(dirInfo.absoluteFilePath(), genreTag, genreTitle, results);
    }
    LOG_TAG("Scanner", "扫描完成，共 " + QString::number(results.size()) + " 首歌曲");
    return results;
}

void SongScanner::scanGenreFolder(const QString &genrePath, const QString &genre,
                                  const QString &genreTitle, QList<SongInfo> &results)
{
    QDir genreDir(genrePath);
    const auto entries = genreDir.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
    int count = 0;
    for (const QFileInfo &entry : entries)
    {
        QDir songDir(entry.absoluteFilePath());
        const auto files = songDir.entryInfoList(QStringList() << "*.tja", QDir::Files, QDir::Name);
        for (const QFileInfo &tjaFile : files)
        {
            SongInfo info = parseTja(tjaFile.absoluteFilePath(), genre, genreTitle);
            if (!info.title.isEmpty())
            {
                results.append(info);
                count++;
            }
        }
    }
    LOG_TAG("Scanner", "  分类 " + genreTitle + ": 解析 " + QString::number(count) + " 首");
}

SongInfo SongScanner::parseTja(const QString &tjaPath, const QString &genre, const QString &genreTitle)
{
    SongInfo info;
    info.filePath = tjaPath;
    info.genre = genre;
    info.genreTitle = genreTitle;

    QString content = readFile(tjaPath);
    if (content.isEmpty())
        return info;

    const QStringList lines = content.split('\n');
    int totalMeasureLines = 0;
    int currentMeasureLines = 0;
    bool inCourse = false;
    bool inScore = false;
    int maxLevel = 0;
    CourseInfo currentCourse;

    for (const QString &line : lines)
    {
        QString l = line.trimmed();
        if (l.isEmpty() || l.startsWith("//"))
            continue;

        if (l.startsWith("TITLE:"))
        {
            info.title = l.mid(6).trimmed();
        }
        else if (l.startsWith("SUBTITLE:"))
        {
            info.subtitle = l.mid(9).trimmed();
        }
        else if (l.startsWith("BPM:"))
        {
            info.bpm = l.mid(4).trimmed().toDouble();
        }
        else if (l.startsWith("WAVE:"))
        {
            info.waveFile = l.mid(5).trimmed();
        }
        else if (l.startsWith("OFFSET:"))
        {
            info.offset = l.mid(7).trimmed().toDouble();
        }
        else if (l.startsWith("DEMOSTART:"))
        {
            info.demoStart = l.mid(10).trimmed().toDouble();
        }
        else if (l.startsWith("COURSE:"))
        {
            if (!currentCourse.course.isEmpty())
                info.courses.append(currentCourse);
            QString rawCourse = l.mid(7).trimmed();
            if (rawCourse == "0")
                currentCourse.course = "Easy";
            else if (rawCourse == "1")
                currentCourse.course = "Normal";
            else if (rawCourse == "2")
                currentCourse.course = "Hard";
            else if (rawCourse == "3")
                currentCourse.course = "Oni";
            else if (rawCourse == "4")
                currentCourse.course = "Ura";
            else if (rawCourse == "5")
                currentCourse.course = "Extra";
            else
            {
                currentCourse.course = rawCourse.trimmed();
                if (!currentCourse.course.isEmpty())
                    currentCourse.course = currentCourse.course.left(1).toUpper() + currentCourse.course.mid(1).toLower();
            }
            currentCourse.level = 0;
            currentCourse.noteCount = 0;
            inCourse = true;
            inScore = false;
        }
        else if (l.startsWith("LEVEL:"))
        {
            if (inCourse)
            {
                int level = l.mid(6).trimmed().toInt();
                currentCourse.level = level;
                if (level > maxLevel)
                    maxLevel = level;
            }
        }
        else if (l.startsWith("SCOREINIT:"))
        {
            if (inCourse)
                inScore = true;
        }
        else if (l.startsWith("#START"))
        {
            inScore = true;
        }
        else if (l.startsWith("#END"))
        {
            inScore = false;
            inCourse = false;
        }
        else if (l.startsWith(","))
        {
            if (inScore)
            {
                totalMeasureLines += currentMeasureLines;
                currentMeasureLines = 0;
            }
        }
        else if (l.startsWith("#GOGOSTART") || l.startsWith("#GOGOEND") ||
                 l.startsWith("#SECTION") || l.startsWith("#BARLINEOFF") ||
                 l.startsWith("#BARLINEON") || l.startsWith("#SCROLL") ||
                 l.startsWith("#DELAY") || l.startsWith("#MEASURE") ||
                 l.startsWith("#BRANCHSTART") || l.startsWith("#BRANCHEND") ||
                 l.startsWith("#N") || l.startsWith("#E") || l.startsWith("#M") ||
                 l.startsWith("#LEVELHOLD"))
        {
        }
        else
        {
            if (inScore)
            {
                currentMeasureLines++;
                totalMeasureLines++;
                // 统计当前 COURSE 的音符数
                for (int i = 0; i < l.length(); ++i)
                {
                    QChar ch = l[i];
                    if (ch == '1' || ch == '2' || ch == '3' || ch == '4' ||
                        ch == '5' || ch == '6' || ch == '7')
                        currentCourse.noteCount++;
                }
            }
        }
    }
    if (!currentCourse.course.isEmpty())
        info.courses.append(currentCourse);

    info.maxLevel = maxLevel;
    if (info.bpm > 0)
        info.estimatedDurationSec = totalMeasureLines * (60.0 / info.bpm);
    return info;
}

double SongScanner::estimateDuration(double bpm, int measureLines)
{
    if (bpm <= 0)
        return 0;
    return measureLines * (60.0 / bpm);
}

// 静态方法：根据文件路径和 COURSE 名称解析完整铺面
CourseChart SongScanner::parseCourseChart(const QString &tjaPath, const QString &courseName)
{
    CourseChart chart;
    chart.course = courseName;

    QString content = readFile(tjaPath);
    if (content.isEmpty())
        return chart;

    const QStringList lines = content.split('\n');
    bool inTarget = false;
    bool inScore = false; // #START / #END 区间
    int measureCount = 0;
    int noteCount = 0;
    int balloonCount = 0;
    int combo = 0;
    int maxCombo = 0;
    double currentBpm = 120;

    for (const QString &line : lines)
    {
        QString l = line.trimmed();
        if (l.isEmpty() || l.startsWith("//"))
            continue;

        if (l.startsWith("TITLE:"))
        {
        }
        else if (l.startsWith("SUBTITLE:"))
        {
        }
        else if (l.startsWith("BPM:"))
        {
            currentBpm = l.mid(4).trimmed().toDouble();
            if (!inTarget)
                chart.bpm = currentBpm;
        }
        else if (l.startsWith("WAVE:"))
        {
        }
        else if (l.startsWith("OFFSET:"))
        {
            chart.offset = l.mid(7).trimmed().toDouble();
        }
        else if (l.startsWith("DEMOSTART:"))
        {
            chart.demoStart = l.mid(10).trimmed().toDouble();
        }
        else if (l.startsWith("BALLOON:"))
        {
            // BALLOON 元数据，跳过（不是谱面行）
        }
        else if (l.startsWith("SCOREINIT:"))
        {
            if (inTarget)
                inScore = true;
        }
        else if (l.startsWith("SCOREDIFF:"))
        {
        }
        else if (l.startsWith("SONGVOL:"))
        {
        }
        else if (l.startsWith("SEVOL:"))
        {
        }
        else if (l.startsWith("COURSE:"))
        {
            QString raw = l.mid(7).trimmed();
            QString norm;
            if (raw == "0")
                norm = "Easy";
            else if (raw == "1")
                norm = "Normal";
            else if (raw == "2")
                norm = "Hard";
            else if (raw == "3")
                norm = "Oni";
            else if (raw == "4")
                norm = "Ura";
            else if (raw == "5")
                norm = "Extra";
            else
            {
                norm = raw.trimmed();
                if (!norm.isEmpty())
                    norm = norm.left(1).toUpper() + norm.mid(1).toLower();
            }
            inTarget = (norm.compare(courseName, Qt::CaseInsensitive) == 0);
            inScore = false;
            if (inTarget)
            {
                chart.course = norm;
                measureCount = 0;
                noteCount = 0;
                balloonCount = 0;
                combo = 0;
                maxCombo = 0;
            }
        }
        else if (l.startsWith("LEVEL:"))
        {
            if (inTarget)
                chart.level = l.mid(6).trimmed().toInt();
        }
        else if (l.startsWith("#START"))
        {
            if (inTarget)
                inScore = true;
        }
        else if (l.startsWith("#END"))
        {
            if (inTarget)
                break;
        }
        else if (l.startsWith("#GOGOSTART") || l.startsWith("#GOGOEND"))
        {
        }
        else if (l.startsWith("#MEASURE") || l.startsWith("#SCROLL") || l.startsWith("#DELAY"))
        {
        }
        else if (l.startsWith("#BRANCHSTART") || l.startsWith("#BRANCHEND") ||
                 l.startsWith("#N") || l.startsWith("#E") || l.startsWith("#M") ||
                 l.startsWith("#LEVELHOLD"))
        {
        }
        else if (l.startsWith(","))
        {
            if (inTarget && inScore)
                measureCount++;
        }
        else if (l.startsWith("#SECTION"))
        {
            if (inTarget)
                chart.sections.append(l.mid(8).trimmed());
        }
        else
        {
            if (inTarget && inScore && !l.startsWith("#"))
            {
                chart.measureLines.append(l);
                for (int i = 0; i < l.length(); ++i)
                {
                    QChar c = l[i];
                    if (c == '1' || c == '2' || c == '3' || c == '4' || c == '5' || c == '6')
                    {
                        noteCount++;
                        combo++;
                        if (combo > maxCombo)
                            maxCombo = combo;
                    }
                    else if (c == '7')
                    {
                        noteCount++;
                        combo++;
                        if (combo > maxCombo)
                            maxCombo = combo;
                    }
                    else if (c == '8')
                    {
                        combo = 0;
                    }
                    else if (c == '9')
                    {
                        balloonCount++;
                    }
                }
            }
        }
    }

    chart.totalNotes = noteCount;
    chart.maxCombo = maxCombo;
    chart.balloonCount = balloonCount;
    return chart;
}