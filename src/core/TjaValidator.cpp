#include "TjaValidator.h"

#include <QFile>
#include <QRegularExpression>
#include <QSet>
#include <QStringDecoder>
#include <QStringEncoder>
#include <QTextStream>

namespace
{
// 单小节字符数上限：超过后部分解析器会崩（见 README「谱面 小节数」）
constexpr int kMaxMeasureChars = 500;
// 24 分以上已经接近人类极限，超过这个瞬时密度基本是排谱事故
constexpr double kMaxNotesPerSecond = 25.0;

QString normalizeCourse(const QString &raw)
{
    const QString r = raw.trimmed();
    if (r == "0")
        return QStringLiteral("Easy");
    if (r == "1")
        return QStringLiteral("Normal");
    if (r == "2")
        return QStringLiteral("Hard");
    if (r == "3")
        return QStringLiteral("Oni");
    if (r == "4")
        return QStringLiteral("Ura");
    if (r == "5")
        return QStringLiteral("Extra");
    if (r.isEmpty())
        return QString();
    return r.left(1).toUpper() + r.mid(1).toLower();
}

// TJA 支持的常见音分分母
bool isLegalDivision(int digits)
{
    static const QSet<int> legal = {1, 2, 3, 4, 6, 8, 12, 16, 24, 32, 48, 64, 96, 192};
    return legal.contains(digits);
}

bool parseDouble(const QString &text, double *out)
{
    bool ok = false;
    const double v = text.trimmed().toDouble(&ok);
    if (!ok)
        return false;
    *out = v;
    return true;
}
} // namespace

// ═══════════════════════════════════════════════════════════════════

QString TjaProblem::severityText() const
{
    switch (severity)
    {
    case Error:
        return QStringLiteral("错误");
    case Warning:
        return QStringLiteral("警告");
    default:
        return QStringLiteral("提示");
    }
}

QVariantMap TjaProblem::toVariantMap() const
{
    QVariantMap map;
    map.insert(QStringLiteral("severity"), static_cast<int>(severity));
    map.insert(QStringLiteral("severityText"), severityText());
    map.insert(QStringLiteral("code"), code);
    map.insert(QStringLiteral("message"), message);
    map.insert(QStringLiteral("hint"), hint);
    map.insert(QStringLiteral("line"), line);
    map.insert(QStringLiteral("measure"), measure);
    return map;
}

// ═══════════════════════════════════════════════════════════════════

QString TjaValidator::decodeFileContent(const QByteArray &raw)
{
    if (raw.isEmpty())
        return QString();

    // 依次尝试 Shift-JIS / UTF-8 / 系统编码，取第一个没有替换字符的结果
    const char *candidates[] = {"Shift-JIS", "UTF-8", "System"};
    for (const char *name : candidates)
    {
        QStringDecoder decoder(name);
        if (!decoder.isValid())
            continue;
        const QString decoded = decoder.decode(raw);
        if (!decoded.contains(QChar(0xFFFD)))
            return decoded;
    }

    QStringDecoder sjis("Shift-JIS");
    if (sjis.isValid())
        return sjis.decode(raw);
    return QString::fromLatin1(raw);
}

bool TjaValidator::canEncodeShiftJis(const QString &text)
{
    QStringEncoder encoder("Shift-JIS");
    if (!encoder.isValid())
        return true; // 没有 ICU 后端时不做判断，避免全部误报
    QStringDecoder decoder("Shift-JIS");
    if (!decoder.isValid())
        return true;
    return decoder.decode(encoder.encode(text)) == text;
}

// ═══════════════════════════════════════════════════════════════════

ChartView TjaValidator::validateText(const QString &tjaText, QList<TjaProblem> *problems)
{
    QList<TjaProblem> found;
    ChartView view;

    auto add = [&found](TjaProblem::Severity severity, const QString &code,
                        const QString &message, const QString &hint,
                        int line, int measure) {
        TjaProblem p;
        p.severity = severity;
        p.code = code;
        p.message = message;
        p.hint = hint;
        p.line = line;
        p.measure = measure;
        found.append(p);
    };

    if (tjaText.isEmpty())
    {
        add(TjaProblem::Error, QStringLiteral("EMPTY_TEXT"),
            QStringLiteral("TJA 内容为空"),
            QStringLiteral("检查文件读取或 AI 返回内容"), -1, -1);
        view.ok = false;
        view.errorCount = 1;
        if (problems)
            *problems = found;
        return view;
    }

    const QStringList lines = tjaText.split(QLatin1Char('\n'));

    bool inScore = false;
    bool sawStart = false;
    bool sawEnd = false;
    bool sawTitle = false;
    bool sawBpm = false;
    bool sawCourse = false;
    bool sawWave = false;
    bool sawBalloonHeader = false;

    double baseBpm = 0.0;
    double currentBpm = 0.0;
    double offset = 0.0;
    double beatsPerMeasure = 4.0; // #MEASURE 影响单小节拍数
    QString courseRaw;
    int level = 0;
    int measureNo = 0;

    int scoreLineCount = 0;
    int noteCount = 0;
    int combo = 0;
    int maxCombo = 0;
    int balloonCount = 0;
    QStringList measureLines;

    struct RollGuard
    {
        bool open = false;
        int code = 0;
        int line = 0;
        int measure = 0;
    } roll;

    static const QRegularExpression reMeasure(QStringLiteral("^#MEASURE\\s+(\\d+)\\s*/\\s*(\\d+)"));

    for (int i = 0; i < lines.size(); ++i)
    {
        const int lineNo = i + 1;
        const QString l = lines.at(i).trimmed();
        if (l.isEmpty() || l.startsWith(QLatin1String("//")))
            continue;

        // ── 头部元数据 ──
        if (l.startsWith(QLatin1String("TITLE:"), Qt::CaseInsensitive))
        {
            sawTitle = true;
            if (l.mid(6).trimmed().isEmpty())
                add(TjaProblem::Warning, QStringLiteral("EMPTY_TITLE"),
                    QStringLiteral("TITLE 为空"), QStringLiteral("游戏内会显示空曲名"), lineNo, -1);
        }
        else if (l.startsWith(QLatin1String("SUBTITLE:"), Qt::CaseInsensitive))
        {
        }
        else if (l.startsWith(QLatin1String("BPM:"), Qt::CaseInsensitive))
        {
            double bpm = 0.0;
            if (!parseDouble(l.mid(4), &bpm) || bpm <= 0.0)
                add(TjaProblem::Error, QStringLiteral("BPM_INVALID"),
                    QStringLiteral("BPM 值非法: %1").arg(l.mid(4).trimmed()),
                    QStringLiteral("BPM 必须是大于 0 的数字，例如 BPM:180"), lineNo, -1);
            else
            {
                sawBpm = true;
                baseBpm = bpm;
                currentBpm = bpm;
            }
        }
        else if (l.startsWith(QLatin1String("WAVE:"), Qt::CaseInsensitive))
        {
            sawWave = true;
            const QString wave = l.mid(5).trimmed();
            if (wave.isEmpty())
                add(TjaProblem::Warning, QStringLiteral("WAVE_EMPTY"),
                    QStringLiteral("WAVE 为空"),
                    QStringLiteral("填写同目录下的 .ogg 文件名，否则游戏没有音轨"), lineNo, -1);
            else if (!wave.endsWith(QLatin1String(".ogg"), Qt::CaseInsensitive))
                add(TjaProblem::Info, QStringLiteral("WAVE_EXT"),
                    QStringLiteral("WAVE 不是 .ogg 文件: %1").arg(wave),
                    QStringLiteral("本家通常使用 .ogg"), lineNo, -1);
        }
        else if (l.startsWith(QLatin1String("OFFSET:"), Qt::CaseInsensitive))
        {
            double v = 0.0;
            if (!parseDouble(l.mid(7), &v))
                add(TjaProblem::Warning, QStringLiteral("OFFSET_INVALID"),
                    QStringLiteral("OFFSET 值非法: %1").arg(l.mid(7).trimmed()),
                    QStringLiteral("留空或写数字，例如 OFFSET:-0.05"), lineNo, -1);
            else
                offset = v;
        }
        else if (l.startsWith(QLatin1String("DEMOSTART:"), Qt::CaseInsensitive))
        {
            double v = 0.0;
            if (!parseDouble(l.mid(10), &v))
                add(TjaProblem::Warning, QStringLiteral("DEMOSTART_INVALID"),
                    QStringLiteral("DEMOSTART 值非法: %1").arg(l.mid(10).trimmed()),
                    QStringLiteral("写数字，单位秒"), lineNo, -1);
        }
        else if (l.startsWith(QLatin1String("SONGVOL:"), Qt::CaseInsensitive) ||
                 l.startsWith(QLatin1String("SEVOL:"), Qt::CaseInsensitive) ||
                 l.startsWith(QLatin1String("SCOREINIT:"), Qt::CaseInsensitive) ||
                 l.startsWith(QLatin1String("SCOREDIFF:"), Qt::CaseInsensitive))
        {
        }
        else if (l.startsWith(QLatin1String("BALLOON:"), Qt::CaseInsensitive))
        {
            sawBalloonHeader = true;
            const QStringList parts = l.mid(8).trimmed().split(QLatin1Char(','), Qt::SkipEmptyParts);
            for (const QString &part : parts)
            {
                bool ok = false;
                const int hits = part.trimmed().toInt(&ok);
                if (!ok || hits <= 0)
                    add(TjaProblem::Warning, QStringLiteral("BALLOON_INVALID"),
                        QStringLiteral("BALLOON 条目非法: %1").arg(part.trimmed()),
                        QStringLiteral("写法为 BALLOON:3,5（每只气球需要的连打数）"), lineNo, -1);
            }
        }
        else if (l.startsWith(QLatin1String("COURSE:"), Qt::CaseInsensitive))
        {
            sawCourse = true;
            courseRaw = normalizeCourse(l.mid(7));
            if (courseRaw.isEmpty())
                add(TjaProblem::Warning, QStringLiteral("COURSE_EMPTY"),
                    QStringLiteral("COURSE 为空"),
                    QStringLiteral("建议写 COURSE:Oni / Hard 等，本工具按难度筛选依赖该字段"), lineNo, -1);
        }
        else if (l.startsWith(QLatin1String("LEVEL:"), Qt::CaseInsensitive))
        {
            bool ok = false;
            const int v = l.mid(6).trimmed().toInt(&ok);
            if (!ok)
                add(TjaProblem::Warning, QStringLiteral("LEVEL_INVALID"),
                    QStringLiteral("LEVEL 值非法: %1").arg(l.mid(6).trimmed()),
                    QStringLiteral("写整数星级，例如 LEVEL:8"), lineNo, -1);
            else
                level = v;
        }
        // ── 谱面指令 ──
        else if (l.startsWith(QLatin1String("#START")))
        {
            sawStart = true;
            inScore = true;
        }
        else if (l.startsWith(QLatin1String("#END")))
        {
            sawEnd = true;
            inScore = false;
        }
        else if (l.startsWith(QLatin1String("#BPMCHANGE")))
        {
            double bpm = 0.0;
            if (!parseDouble(l.mid(10), &bpm) || bpm <= 0.0)
                add(TjaProblem::Error, QStringLiteral("BPMCHANGE_INVALID"),
                    QStringLiteral("#BPMCHANGE 值非法: %1").arg(l.mid(10).trimmed()),
                    QStringLiteral("写法为 #BPMCHANGE 150.5"), lineNo, measureNo);
            else
                currentBpm = bpm;
        }
        else if (l.startsWith(QLatin1String("#MEASURE")))
        {
            const QRegularExpressionMatch m = reMeasure.match(l);
            if (!m.hasMatch())
                add(TjaProblem::Error, QStringLiteral("MEASURE_SYNTAX"),
                    QStringLiteral("#MEASURE 参数非法: %1").arg(l),
                    QStringLiteral("写法为 #MEASURE 4/4 或 #MEASURE 3/4"), lineNo, measureNo);
            else
            {
                const int num = m.captured(1).toInt();
                const int den = m.captured(2).toInt();
                if (num <= 0 || den <= 0)
                    add(TjaProblem::Error, QStringLiteral("MEASURE_RATIO"),
                        QStringLiteral("#MEASURE 分子分母必须大于 0: %1").arg(l),
                        QStringLiteral("常见值为 4/4、3/4、6/8"), lineNo, measureNo);
                else
                    beatsPerMeasure = 4.0 * num / den;
            }
        }
        else if (l.startsWith(QLatin1String("#SCROLL")))
        {
            double v = 0.0;
            if (!parseDouble(l.mid(7), &v))
                add(TjaProblem::Warning, QStringLiteral("SCROLL_INVALID"),
                    QStringLiteral("#SCROLL 值非法: %1").arg(l.mid(7).trimmed()),
                    QStringLiteral("写法为 #SCROLL 1.5"), lineNo, measureNo);
        }
        else if (l.startsWith(QLatin1String("#DELAY")))
        {
            double v = 0.0;
            if (!parseDouble(l.mid(6), &v))
                add(TjaProblem::Warning, QStringLiteral("DELAY_INVALID"),
                    QStringLiteral("#DELAY 值非法: %1").arg(l.mid(6).trimmed()),
                    QStringLiteral("写法为 #DELAY 0.5（单位秒）"), lineNo, measureNo);
        }
        else if (l.startsWith(QLatin1String("#GOGOSTART")) ||
                 l.startsWith(QLatin1String("#GOGOEND")) ||
                 l.startsWith(QLatin1String("#BARLINEOFF")) ||
                 l.startsWith(QLatin1String("#BARLINEON")) ||
                 l.startsWith(QLatin1String("#SECTION")) ||
                 l.startsWith(QLatin1String("#BRANCHSTART")) ||
                 l.startsWith(QLatin1String("#BRANCHEND")) ||
                 l.startsWith(QLatin1String("#LEVELHOLD")) ||
                 l.startsWith(QLatin1String("#N")) ||
                 l.startsWith(QLatin1String("#E")) ||
                 l.startsWith(QLatin1String("#M")))
        {
        }
        else if (l.startsWith(QLatin1Char('#')))
        {
            // 未知指令：AI 生成最常见的错误之一就是凭空造指令
            add(TjaProblem::Warning, QStringLiteral("UNKNOWN_COMMAND"),
                QStringLiteral("未知指令: %1").arg(l.section(QLatin1Char(' '), 0, 0)),
                QStringLiteral("检查是否拼错，可用指令见 TJA 语法文档"), lineNo, measureNo);
        }
        // ── 小节分隔 ──
        else if (l.startsWith(QLatin1Char(',')))
        {
            measureNo++;
        }
        // ── 谱面数据行 ──
        else
        {
            if (!inScore)
            {
                add(TjaProblem::Warning, QStringLiteral("DATA_OUTSIDE_SCORE"),
                    QStringLiteral("谱面数据出现在 #START 之外: %1").arg(l.left(24)),
                    QStringLiteral("把音符数据放进 #START / #END 区间"), lineNo, -1);
                continue;
            }

            QString data = l;
            const int commentPos = data.indexOf(QLatin1String("//"));
            if (commentPos >= 0)
                data = data.left(commentPos).trimmed();
            data.remove(QLatin1Char(' '));
            data.remove(QLatin1Char('\t'));

            // TJA 惯例是每个小节行尾加逗号：1010..., 先把它们摘掉并记作小节分隔
            int trailingCommas = 0;
            while (data.endsWith(QLatin1Char(',')))
            {
                data.chop(1);
                trailingCommas++;
            }
            const int step = qMax(1, trailingCommas);
            if (data.isEmpty())
            {
                measureNo += step;
                continue;
            }

            if (measureNo <= 0)
                measureNo = 1;

            // 字符白名单：只允许 0-9
            bool illegal = false;
            for (const QChar ch : data)
            {
                if (!ch.isDigit())
                {
                    add(TjaProblem::Error, QStringLiteral("ILLEGAL_CHAR"),
                        QStringLiteral("谱面行出现非法字符 \"%1\"").arg(QString(ch)),
                        QStringLiteral("谱面行只能包含 0-9；逗号用于分隔小节，指令以 # 开头"),
                        lineNo, measureNo);
                    illegal = true;
                    break;
                }
            }
            if (illegal)
            {
                measureNo += step;
                continue;
            }

            const int digits = data.size();
            scoreLineCount++;
            measureLines.append(data);

            if (digits > kMaxMeasureChars)
                add(TjaProblem::Error, QStringLiteral("MEASURE_TOO_LONG"),
                    QStringLiteral("小节 %1 有 %2 个字符，超过 %3 上限")
                        .arg(QString::number(measureNo), QString::number(digits), QString::number(kMaxMeasureChars)),
                    QStringLiteral("拆分该小节，或降低音分精度（改用 1/16、1/24）"),
                    lineNo, measureNo);
            else if (digits > 192)
                add(TjaProblem::Warning, QStringLiteral("MEASURE_FINE_DIVISION"),
                    QStringLiteral("小节 %1 的 1/%2 音分过细")
                        .arg(QString::number(measureNo), QString::number(digits)),
                    QStringLiteral("超过 1/192 基本无法准确读谱，检查是否写多了字符"),
                    lineNo, measureNo);

            if (!isLegalDivision(digits))
                add(TjaProblem::Info, QStringLiteral("NON_STANDARD_DIVISION"),
                    QStringLiteral("小节 %1 有 %2 个字符，对应 1/%2 音分")
                        .arg(QString::number(measureNo), QString::number(digits)),
                    QStringLiteral("常见音分为 1/4、1/8、1/12、1/16、1/24、1/32"),
                    lineNo, measureNo);

            int lineNotes = 0;
            for (const QChar ch : data)
            {
                const int d = ch.digitValue();
                switch (d)
                {
                case 0:
                    break;
                case 1:
                case 2:
                case 3:
                case 4:
                    lineNotes++;
                    noteCount++;
                    combo++;
                    if (combo > maxCombo)
                        maxCombo = combo;
                    break;
                case 5:
                case 6:
                case 7:
                    lineNotes++;
                    noteCount++;
                    combo++;
                    if (combo > maxCombo)
                        maxCombo = combo;
                    if (roll.open)
                        add(TjaProblem::Error, QStringLiteral("ROLL_NESTED"),
                            QStringLiteral("连打开始符 %1 出现在未闭合的连打（始于第 %2 行）内")
                                .arg(QString::number(d), QString::number(roll.line)),
                            QStringLiteral("一个连打必须以 8 结束，再开始下一个"),
                            lineNo, measureNo);
                    else
                    {
                        roll.open = true;
                        roll.code = d;
                        roll.line = lineNo;
                        roll.measure = measureNo;
                    }
                    break;
                case 9:
                    balloonCount++;
                    if (roll.open)
                        add(TjaProblem::Error, QStringLiteral("ROLL_NESTED"),
                            QStringLiteral("地瓜连打 9 出现在未闭合的连打（始于第 %1 行）内")
                                .arg(QString::number(roll.line)),
                            QStringLiteral("一个连打必须以 8 结束，再开始下一个"),
                            lineNo, measureNo);
                    else
                    {
                        roll.open = true;
                        roll.code = 9;
                        roll.line = lineNo;
                        roll.measure = measureNo;
                    }
                    break;
                case 8:
                    if (!roll.open)
                        add(TjaProblem::Error, QStringLiteral("ROLL_UNMATCHED_END"),
                            QStringLiteral("连打结束符 8 没有对应的开始符(5/6/7/9)"),
                            QStringLiteral("连打写法为 500008 或 555558"),
                            lineNo, measureNo);
                    roll.open = false;
                    combo = 0;
                    break;
                default:
                    break;
                }
            }

            const double bpmForMeasure = currentBpm > 0.0 ? currentBpm : 120.0;
            const double measureSeconds = beatsPerMeasure * 60.0 / bpmForMeasure;
            if (measureSeconds > 0.0 && lineNotes / measureSeconds > kMaxNotesPerSecond)
                add(TjaProblem::Warning, QStringLiteral("DENSITY_HIGH"),
                    QStringLiteral("小节 %1 瞬时密度约 %2 NPS，超过 %3")
                        .arg(QString::number(measureNo),
                             QString::number(lineNotes / measureSeconds, 'f', 1),
                             QString::number(kMaxNotesPerSecond, 'f', 0)),
                    QStringLiteral("降低该小节的音符密度，或确认 BPM 是否正确"),
                    lineNo, measureNo);

            if (lineNotes == 0)
                add(TjaProblem::Info, QStringLiteral("EMPTY_MEASURE"),
                    QStringLiteral("小节 %1 没有音符").arg(measureNo),
                    QStringLiteral("整小节空拍是合法的，确认不是漏写"),
                    lineNo, measureNo);

            measureNo += step;
        }
    }

    // ── 收尾检查 ──
    if (roll.open)
        add(TjaProblem::Error, QStringLiteral("ROLL_UNCLOSED"),
            QStringLiteral("连打（起始符 %1）未闭合").arg(QString::number(roll.code)),
            QStringLiteral("连打必须用 8 结束，例如 500008"),
            roll.line, roll.measure);

    if (!sawStart)
        add(TjaProblem::Error, QStringLiteral("NO_START"),
            QStringLiteral("缺少 #START"),
            QStringLiteral("谱面数据必须包在 #START 与 #END 之间"), -1, -1);
    else if (!sawEnd)
        add(TjaProblem::Warning, QStringLiteral("NO_END"),
            QStringLiteral("缺少 #END"),
            QStringLiteral("补上 #END，部分解析器会截断或报错"), -1, -1);

    if (!sawBpm)
        add(TjaProblem::Error, QStringLiteral("NO_BPM"),
            QStringLiteral("缺少 BPM 头"),
            QStringLiteral("TJA 必须有 BPM: 行，否则谱面无法对时"), -1, -1);
    if (!sawTitle)
        add(TjaProblem::Warning, QStringLiteral("NO_TITLE"),
            QStringLiteral("缺少 TITLE"),
            QStringLiteral("游戏内会显示空曲名"), -1, -1);
    if (!sawCourse)
        add(TjaProblem::Warning, QStringLiteral("NO_COURSE"),
            QStringLiteral("缺少 COURSE"),
            QStringLiteral("写 COURSE:Oni 等，本工具按难度筛选依赖该字段"), -1, -1);
    if (!sawWave)
        add(TjaProblem::Info, QStringLiteral("NO_WAVE"),
            QStringLiteral("缺少 WAVE"),
            QStringLiteral("填写音频文件名后游戏才会播放音轨"), -1, -1);
    if (scoreLineCount == 0)
        add(TjaProblem::Error, QStringLiteral("NO_SCORE"),
            QStringLiteral("#START 与 #END 之间没有谱面数据"),
            QStringLiteral("至少写入一个小节的数据"), -1, -1);
    if (balloonCount > 0 && !sawBalloonHeader)
        add(TjaProblem::Warning, QStringLiteral("BALLOON_HEADER_MISSING"),
            QStringLiteral("谱面含气球(7)但缺少 BALLOON 头"),
            QStringLiteral("补 BALLOON:3,5 之类的行，否则气球数不正确"), -1, -1);

    // 编码：TJA 传统为 Shift-JIS，emoji / 生僻字会让游戏读成乱码
    if (!canEncodeShiftJis(tjaText))
    {
        QStringList offenders;
        for (const QChar ch : tjaText)
        {
            if (offenders.size() >= 5)
                break;
            if (!canEncodeShiftJis(QString(ch)))
                offenders.append(QString(ch));
        }
        add(TjaProblem::Warning, QStringLiteral("ENCODING_NOT_SJIS"),
            QStringLiteral("含 Shift-JIS 无法表示的字符: %1").arg(offenders.join(QLatin1Char(' '))),
            QStringLiteral("保存时需改用 UTF-8，或替换掉 emoji / 生僻字"), -1, -1);
    }

    // ── 汇总 ──
    view.course = courseRaw.isEmpty() ? QStringLiteral("Unknown") : courseRaw;
    view.level = level;
    view.bpm = baseBpm > 0.0 ? baseBpm : 120.0;
    view.offset = offset;
    view.totalNotes = noteCount;
    view.maxCombo = maxCombo;
    view.balloonCount = balloonCount;
    view.measureCount = scoreLineCount;
    view.measureLines.clear();
    view.measureLines.reserve(measureLines.size());
    for (const QString &line : measureLines)
        view.measureLines.append(line);

    view.ok = true;
    view.errorCount = 0;
    view.warningCount = 0;
    for (const TjaProblem &p : found)
    {
        if (p.severity == TjaProblem::Error)
        {
            view.ok = false;
            view.errorCount++;
        }
        else if (p.severity == TjaProblem::Warning)
        {
            view.warningCount++;
        }
    }

    if (problems)
        *problems = found;
    return view;
}

ChartView TjaValidator::validateFile(const QString &filePath, QList<TjaProblem> *problems)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly))
    {
        QList<TjaProblem> found;
        TjaProblem p;
        p.severity = TjaProblem::Error;
        p.code = QStringLiteral("FILE_UNREADABLE");
        p.message = QStringLiteral("无法打开文件: %1").arg(filePath);
        p.hint = QStringLiteral("检查路径与权限");
        found.append(p);

        ChartView view;
        view.ok = false;
        view.errorCount = 1;
        if (problems)
            *problems = found;
        return view;
    }

    const QByteArray raw = file.readAll();
    file.close();
    return validateText(decodeFileContent(raw), problems);
}

QVariantList TjaValidator::toVariantList(const QList<TjaProblem> &problems)
{
    QVariantList list;
    list.reserve(problems.size());
    for (const TjaProblem &p : problems)
        list.append(p.toVariantMap());
    return list;
}

QString TjaValidator::reportText(const ChartView &view, const QList<TjaProblem> &problems)
{
    QString out;
    QTextStream ts(&out);
    ts << "难度/星级 : " << view.course << "  ★" << view.level << "\n";
    ts << "统计      : 音符 " << view.totalNotes
       << " | 最大连击 " << view.maxCombo
       << " | 气球 " << view.balloonCount
       << " | 小节 " << view.measureCount
       << " | BPM " << view.bpm << "\n";
    ts << "结论      : " << (view.ok ? QStringLiteral("通过") : QStringLiteral("未通过"))
       << "  (" << view.errorCount << " 错误 / " << view.warningCount << " 警告)\n";

    if (!problems.isEmpty())
    {
        ts << "----------------------------------------\n";
        for (const TjaProblem &p : problems)
        {
            ts << '[' << p.severityText() << "] ";
            if (p.line > 0)
                ts << "第 " << p.line << " 行 ";
            if (p.measure > 0)
                ts << "(小节 " << p.measure << ") ";
            ts << p.code << "\n";
            ts << "    " << p.message << "\n";
            if (!p.hint.isEmpty())
                ts << "    建议: " << p.hint << "\n";
        }
    }
    return out;
}
