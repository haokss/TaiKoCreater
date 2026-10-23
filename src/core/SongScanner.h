#ifndef SONGSCANNER_H
#define SONGSCANNER_H

#include <QObject>
#include <QString>
#include <QList>
#include "SongInfo.h"

class SongScanner : public QObject
{
    Q_OBJECT
public:
    explicit SongScanner(QObject *parent = nullptr);

    QList<SongInfo> scanFolder(const QString &rootPath);

    // 解析指定 COURSE 的完整铺面数据
    static CourseChart parseCourseChart(const QString &tjaPath, const QString &courseName);

private:
    SongInfo parseTja(const QString &tjaPath, const QString &genre, const QString &genreTitle);
    void scanGenreFolder(const QString &genrePath, const QString &genre, const QString &genreTitle,
                         QList<SongInfo> &results);
    double estimateDuration(double bpm, int measureLines);
};

#endif // SONGSCANNER_H