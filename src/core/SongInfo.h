#ifndef SONGINFO_H
#define SONGINFO_H

#include <QString>
#include <QList>
#include <QStringList>

struct CourseInfo {
    QString course;       // COURSE 名称: Oni, Hard, Normal, Easy
    int level = 0;        // LEVEL 星级
    int noteCount = 0;    // 音符数量 (不含 0/8/9)
};

// 单行谱面信息
struct MeasureLine {
    QString data;      // 原始谱面字符串 (如 "100000100000200000")
    int bpm = 0;       // 该小节时的 BPM（0 = 沿用前一小节）
    bool gogo = false; // 是否处于 GO-GO 时段
};

struct CourseChart {
    QString course;       // 难度名
    int level = 0;        // 星级
    double bpm = 120;     // 基准 BPM
    double offset = 0;    // OFFSET
    double demoStart = 0; // DEMOSTART
    int totalNotes = 0;   // 总音符数（非0/非8/非9的谱面行）
    int maxCombo = 0;     // 最大连击（粗略计算）
    int balloonCount = 0; // 气球/连打数
    QStringList measureLines; // 完整谱面行列表
    QStringList sections;     // 谱面分段标题
};

struct SongInfo {
    QString title;
    QString subtitle;
    QString genre;
    QString genreTitle;
    int maxLevel = 0;
    double bpm = 120;
    QString waveFile;
    double offset = 0;
    double demoStart = 0;
    QString filePath;
    double estimatedDurationSec = 0;
    QList<CourseInfo> courses;
};

#endif // SONGINFO_H