#include "DeepSeekClient.h"
#include "../utils/Logger.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QUrl>
#include <QUrlQuery>
#include <QNetworkRequest>
#include <QFileInfo>
#include <QFile>
#include <QDir>
#include <QCoreApplication>
#include <QRegularExpression>

namespace
{
// API Key 不再硬编码进源码（仓库是公开的）。
// 优先级：环境变量 DEEPSEEK_API_KEY > 程序目录下 config.json 的 deepseekApiKey 字段 > 空
QString resolveApiKey()
{
    const QString fromEnv = qEnvironmentVariable("DEEPSEEK_API_KEY").trimmed();
    if (!fromEnv.isEmpty())
        return fromEnv;

    const QString configPath = QDir(QCoreApplication::applicationDirPath()).filePath("config.json");
    QFile file(configPath);
    if (file.open(QIODevice::ReadOnly))
    {
        const QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
        file.close();
        const QString fromFile = doc.object().value(QStringLiteral("deepseekApiKey")).toString().trimmed();
        if (!fromFile.isEmpty())
            return fromFile;
    }
    return QString();
}
} // namespace

DeepSeekClient::DeepSeekClient(QObject *parent)
    : QObject(parent)
    , m_network(new QNetworkAccessManager(this))
{
    m_apiKey = resolveApiKey();
    if (m_apiKey.isEmpty())
        LOG_TAG("DeepSeek", "未找到 API Key（环境变量 DEEPSEEK_API_KEY 或 config.json）");
    connect(m_network, &QNetworkAccessManager::finished,
            this, &DeepSeekClient::onReplyFinished);
}

void DeepSeekClient::setApiKey(const QString &key)
{
    if (m_apiKey != key) {
        m_apiKey = key;
        emit apiKeyChanged();
    }
}

void DeepSeekClient::generateTJA(const QString &oggFilePath,
                                  const QString &genre,
                                  const QString &difficulty,
                                  int targetLevel,
                                  int targetBpm,
                                  bool withVariation,
                                  bool withGogo,
                                  bool withBranch,
                                  double density)
{
    if (m_busy) {
        emit generationFailed("上一次生成尚未完成");
        return;
    }

    if (m_apiKey.isEmpty()) {
        emit generationFailed("请先设置 DeepSeek API Key");
        return;
    }

    // QML FileDialog 传过来的是 URL (file:///D:/path/to/file.ogg)，需转为本地路径
    QString localPath = oggFilePath;
    QUrl url(localPath);
    if (url.isLocalFile())
        localPath = url.toLocalFile();

    QFileInfo fi(localPath);
    if (!fi.exists() || localPath.isEmpty()) {
        LOG_TAG("DeepSeek", "文件不存在: raw=" + oggFilePath + " local=" + localPath);
        emit generationFailed("音频文件不存在: " + localPath);
        return;
    }

    m_busy = true;
    emit busyChanged();
    emit generationProgress("正在构建请求...");

    // 构建请求体
    QJsonObject requestBody;
    requestBody["model"] = QStringLiteral("deepseek-chat");
    requestBody["max_tokens"] = 8192;
    requestBody["temperature"] = 0.7;

    // 系统提示
    QJsonObject systemMsg;
    systemMsg["role"] = QStringLiteral("system");
    systemMsg["content"] = buildSystemPrompt();

    // 用户提示
    QJsonObject userMsg;
    userMsg["role"] = QStringLiteral("user");
    userMsg["content"] = buildUserPrompt(fi.fileName(), genre, difficulty,
                                          targetLevel, targetBpm,
                                          withVariation, withGogo,
                                          withBranch, density);

    QJsonArray messages;
    messages.append(systemMsg);
    messages.append(userMsg);
    requestBody["messages"] = messages;

    QNetworkRequest request(QUrl("https://api.deepseek.com/chat/completions"));
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    request.setRawHeader("Authorization", ("Bearer " + m_apiKey).toUtf8());

    QByteArray jsonData = QJsonDocument(requestBody).toJson(QJsonDocument::Compact);
    LOG_TAG("DeepSeek", "发送生成请求, genre=" + genre + " diff=" + difficulty
            + " level=" + QString::number(targetLevel) + " bpm=" + QString::number(targetBpm));

    m_activeReply = m_network->post(request, jsonData);
    emit generationProgress("已发送请求，等待 AI 响应...");
}

void DeepSeekClient::cancelGeneration()
{
    if (m_activeReply) {
        m_activeReply->abort();
        m_activeReply->deleteLater();
        m_activeReply = nullptr;
        m_busy = false;
        emit busyChanged();
        emit generationProgress("已取消");
    }
}

void DeepSeekClient::onReplyFinished(QNetworkReply *reply)
{
    if (reply != m_activeReply) {
        reply->deleteLater();
        return;
    }
    m_activeReply = nullptr;
    m_busy = false;
    emit busyChanged();

    if (reply->error() == QNetworkReply::OperationCanceledError) {
        reply->deleteLater();
        return;
    }

    if (reply->error() != QNetworkReply::NoError) {
        QString err = "网络错误: " + reply->errorString();
        LOG_TAG("DeepSeek", err);
        emit generationFailed(err);
        reply->deleteLater();
        return;
    }

    QByteArray responseData = reply->readAll();
    reply->deleteLater();

    QJsonParseError parseError;
    QJsonDocument doc = QJsonDocument::fromJson(responseData, &parseError);
    if (parseError.error != QJsonParseError::NoError) {
        emit generationFailed("解析响应 JSON 失败: " + parseError.errorString());
        return;
    }

    QJsonObject root = doc.object();
    QJsonArray choices = root["choices"].toArray();
    if (choices.isEmpty()) {
        // 可能是错误响应
        QJsonObject errObj = root["error"].toObject();
        if (!errObj.isEmpty()) {
            emit generationFailed("API 错误: " + errObj["message"].toString());
        } else {
            emit generationFailed("AI 未返回有效响应");
        }
        return;
    }

    QString content = choices[0].toObject()["message"].toObject()["content"].toString();
    LOG_TAG("DeepSeek", "收到响应, 长度=" + QString::number(content.length()));

    // 从 Markdown 代码块中提取 TJA 内容
    QString tjaContent = extractTJAFromResponse(content);
    if (tjaContent.isEmpty()) {
        emit generationFailed("AI 响应中未找到有效的 TJA 谱面内容");
        return;
    }

    emit generationCompleted(tjaContent);
}

QString DeepSeekClient::extractTJAFromResponse(const QString &responseText) const
{
    // 尝试匹配 ```tja ... ``` 或 ``` ... ``` 代码块
    QRegularExpression tjaBlock(R"(```(?:tja)?\s*\n([\s\S]*?)\n```)");
    QRegularExpressionMatch match = tjaBlock.match(responseText);
    if (match.hasMatch()) {
        return match.captured(1).trimmed();
    }

    // 如果没有代码块，检查是否整个响应就是 TJA 内容
    if (responseText.contains("TITLE:") && responseText.contains("BPM:")) {
        return responseText.trimmed();
    }

    return QString();
}

QString DeepSeekClient::buildSystemPrompt() const
{
    return QStringLiteral(
        "你是一个专业的太鼓达人（Taiko no Tatsujin）谱面制作 AI。"
        "你会根据用户的参数要求，生成一个完整的 .tja 格式谱面文件。\n\n"
        "## TJA 文件格式规范\n"
        "- 文件以 TITLE:, SUBTITLE:, BPM:, WAVE:, OFFSET:, DEMOSTART: 等元数据开头\n"
        "- COURSE: 后跟难度名（Easy/Normal/Hard/Oni/Ura），LEVEL: 后跟星级 1-10\n"
        "- 每个 COURSE 段以 #START 开始，以 #END 结束\n"
        "- 谱面行由数字 0-9 和逗号组成：\n"
        "  - 0: 空拍\n"
        "  - 1: 咚 (Don) 小音符\n"
        "  - 2: 咔 (Ka) 小音符\n"
        "  - 3: 咚 大音符\n"
        "  - 4: 咔 大音符\n"
        "  - 5: 连打/条\n"
        "  - 6: 大连打/条\n"
        "  - 7: 气球\n"
        "  - 8: 结束/转场\n"
        "  - 9: 连打（另一种）/ 特殊\n"
        "  - 逗号(,): 小节分隔\n"
        "- #GOGOSTART / #GOGOEND 标记 GO-GO TIME 段落\n"
        "- #SECTION 后跟段落标题\n"
        "- #MEASURE x/y 可指定拍号\n"
        "- 每行 16 个字符对应一小节（4/4 拍下 16 分音符）\n\n"
        "## 输出要求\n"
        "- 请生成一个完整结构的 .tja 文件\n"
        "- 整首曲子应有合理的段落（intro, verse, chorus, bridge, outro 等）\n"
        "- 音符模式应符合该难度级别的风格"
        "- 返回时放在```tja ... ```代码块中");
}

QString DeepSeekClient::buildUserPrompt(const QString &oggFileName,
                                         const QString &genre,
                                         const QString &difficulty,
                                         int targetLevel,
                                         int targetBpm,
                                         bool withVariation,
                                         bool withGogo,
                                         bool withBranch,
                                         double density) const
{
    // 难度星级对应的音符密度映射
    QString densityGuide;
    if (difficulty == "Easy") {
        densityGuide = "低密度，主要为 1 和 2，少量 3 和 4，无连打";
    } else if (difficulty == "Normal") {
        densityGuide = "中低密度，加入更多 3/4 大音符和简单 5 连打";
    } else if (difficulty == "Hard") {
        densityGuide = "中高密度，有节奏变化，适当加入 7 气球和 6 大连打";
    } else if (difficulty == "Ura") {
        densityGuide = "高密度，复杂节奏，大量连打和气球，分支谱面";
    } else {
        // Oni
        densityGuide = "高密度达人谱面，复杂节奏变化，大量连打气球，最大程度发挥太鼓技巧";
    }

    QString prompt = QString(
        "请根据以下参数生成一个太鼓达人谱面（.tja 格式）：\n\n"
        "## 基本参数\n"
        "- 歌曲文件名: %1\n"
        "- 流派: %2\n"
        "- 难度: %3\n"
        "- 目标星级: ★%4\n"
        "- BPM: %5\n\n"
        "## 风格要求\n"
        "- 密度等级: %6\n"
        "- 节奏变化: %7\n"
        "- 包含 GO-GO TIME: %8\n"
        "- 包含分支谱面: %9\n"
        "- 音符密度系数: %10\n\n"
        "## 谱面结构要求\n"
        "1. 请包含完整的元数据头（TITLE/SUBTITLE/BPM/WAVE/OFFSET/DEMOSTART）\n"
        "2. 请生成 %3 难度的 COURSE 段，星级为 %4\n"
        "3. 谱面应有 60-120 行（对应小节数）\n"
        "4. 请使用 #SECTION 给不同段落命名（如 Intro, Verse, Chorus 等）\n"
        "5. 确保节奏符合 %3 难度特征\n"
        "6. 在适当的段落使用 %11 GO-GO TIME\n"
        "7. 整首曲子应有起承转合的感觉\n\n"
        "请开始生成完整的 .tja 文件内容。")
        .arg(oggFileName)
        .arg(genre)
        .arg(difficulty)
        .arg(targetLevel)
        .arg(targetBpm)
        .arg(densityGuide)
        .arg(withVariation ? "是 - 请加入切分音、三连音等节奏变化" : "否 - 保持基本节奏")
        .arg(withGogo ? "是 - 请在合适的段落加入 GO-GO TIME" : "否")
        .arg(withBranch ? "是 - 请包含 #BRANCHSTART 分支谱面" : "否")
        .arg(density, 0, 'f', 2)
        .arg(withGogo ? "包含" : "不包含");

    return prompt;
}