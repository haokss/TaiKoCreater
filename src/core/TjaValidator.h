#ifndef TJAVALIDATOR_H
#define TJAVALIDATOR_H

#include <QByteArray>
#include <QList>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

#include "ChartData.h"

// ═══════════════════════════════════════════════════════════════════
// TjaProblem —— 一条校验问题
// 纯数据，不含 Qt GUI 依赖，方便单测与 CLI 复用。
// ═══════════════════════════════════════════════════════════════════
struct TjaProblem
{
    enum Severity
    {
        Error = 0, // 必然导致游戏加载失败或谱面错乱
        Warning = 1, // 可能有问题，建议修
        Info = 2 // 风格提示
    };

    Severity severity = Error;
    QString code;    // 机器可读的问题码，如 MEASURE_TOO_LONG
    QString message; // 人类可读描述
    QString hint;    // 修复建议
    int line = -1;   // 1-based 行号，-1 表示不适用
    int measure = -1; // 1-based 小节序号，-1 表示不适用

    QString severityText() const;
    QVariantMap toVariantMap() const;
    bool isBlocking() const { return severity == Error; }
};

// ═══════════════════════════════════════════════════════════════════
// TjaValidator —— TJA 谱面解析 + 合法性校验（纯函数层）
//
// 所有方法都是静态无状态的，不依赖 GUI、不依赖 Logger，
// 因此可以被 UI、CLI、单元测试三方共用。
// ═══════════════════════════════════════════════════════════════════
class TjaValidator
{
public:
    // 解析文本并校验，返回归一化后的 ChartView（含统计与结论）
    static ChartView validateText(const QString &tjaText, QList<TjaProblem> *problems = nullptr);

    // 读文件（自动识别 Shift-JIS / UTF-8 / 系统编码）后校验
    static ChartView validateFile(const QString &filePath, QList<TjaProblem> *problems = nullptr);

    static QVariantList toVariantList(const QList<TjaProblem> &problems);

    // 人类可读报告，供 CLI 与日志输出
    static QString reportText(const ChartView &view, const QList<TjaProblem> &problems);

    // 编码工具：TJA 传统上是 Shift-JIS，含 emoji/生僻字会编不出来
    static QString decodeFileContent(const QByteArray &raw);
    static bool canEncodeShiftJis(const QString &text);

private:
    TjaValidator() = delete;
};

#endif // TJAVALIDATOR_H
