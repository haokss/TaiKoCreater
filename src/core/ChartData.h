#ifndef CHARTDATA_H
#define CHARTDATA_H

#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <QMetaObject>
#include <QMetaProperty>
#include <QList>

#include "SongInfo.h"

// ═══════════════════════════════════════════════════════════════════
// ChartView —— 谱面数据的唯一契约（C++ ↔ QML 边界）
//
// 设计要点：
//   1. 字段即属性（Q_PROPERTY），改名只需改这里一处；
//   2. toVariantMap() 通过元对象自动导出，键名与属性名恒等，
//      不存在"手写 map 键与属性名对不上"的漂移；
//   3. 所有解析路径（磁盘 TJA / AI 生成文本）都先归一化成
//      ChartView，再交给 UI，QML 侧只认这一组字段。
//
// QML 侧可读字段：
//   course / level / bpm / offset / totalNotes / maxCombo /
//   balloonCount / measureCount / measureLines /
//   ok / errorCount / warningCount
// ═══════════════════════════════════════════════════════════════════
struct ChartView
{
    Q_GADGET
    Q_PROPERTY(QString course MEMBER course)
    Q_PROPERTY(int level MEMBER level)
    Q_PROPERTY(double bpm MEMBER bpm)
    Q_PROPERTY(double offset MEMBER offset)
    Q_PROPERTY(int totalNotes MEMBER totalNotes)
    Q_PROPERTY(int maxCombo MEMBER maxCombo)
    Q_PROPERTY(int balloonCount MEMBER balloonCount)
    Q_PROPERTY(int measureCount MEMBER measureCount)
    Q_PROPERTY(QVariantList measureLines MEMBER measureLines)
    Q_PROPERTY(bool ok MEMBER ok)
    Q_PROPERTY(int errorCount MEMBER errorCount)
    Q_PROPERTY(int warningCount MEMBER warningCount)

public:
    QString course = QStringLiteral("Unknown");
    int level = 0;
    double bpm = 120.0;
    double offset = 0.0;
    int totalNotes = 0;
    int maxCombo = 0;
    int balloonCount = 0;
    int measureCount = 0;
    QVariantList measureLines;

    // 校验结论（由 TjaValidator 填充）
    bool ok = true;
    int errorCount = 0;
    int warningCount = 0;

    static ChartView fromChart(const CourseChart &chart)
    {
        ChartView v;
        v.course = chart.course.isEmpty() ? QStringLiteral("Unknown") : chart.course;
        v.level = chart.level;
        v.bpm = chart.bpm;
        v.offset = chart.offset;
        v.totalNotes = chart.totalNotes;
        v.maxCombo = chart.maxCombo;
        v.balloonCount = chart.balloonCount;
        v.measureCount = chart.measureLines.size();
        v.measureLines.reserve(chart.measureLines.size());
        for (const QString &line : chart.measureLines)
            v.measureLines.append(line);
        return v;
    }

    // 由元对象导出 QVariantMap：键名 == 属性名，避免两处手写字符串。
    QVariantMap toVariantMap() const
    {
        QVariantMap map;
        const QMetaObject &mo = ChartView::staticMetaObject;
        const int count = mo.propertyCount();
        for (int i = 0; i < count; ++i)
        {
            const QMetaProperty prop = mo.property(i);
            map.insert(QString::fromLatin1(prop.name()), prop.readOnGadget(this));
        }
        return map;
    }
};

#endif // CHARTDATA_H
