#ifndef DEEPSEEKCLIENT_H
#define DEEPSEEKCLIENT_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QJsonObject>
#include <QJsonArray>

class DeepSeekClient : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString apiKey READ apiKey WRITE setApiKey NOTIFY apiKeyChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)

public:
    explicit DeepSeekClient(QObject *parent = nullptr);

    QString apiKey() const { return m_apiKey; }
    void setApiKey(const QString &key);
    bool busy() const { return m_busy; }

    // 请求 AI 生成 TJA 谱面
    Q_INVOKABLE void generateTJA(const QString &oggFilePath,
                                  const QString &genre,
                                  const QString &difficulty,
                                  int targetLevel,
                                  int targetBpm,
                                  bool withVariation,
                                  bool withGogo,
                                  bool withBranch,
                                  double density);

    // 取消当前请求
    Q_INVOKABLE void cancelGeneration();

signals:
    void apiKeyChanged();
    void busyChanged();

    // 生成成功，tjaContent 是完整的 .tja 文件文本
    void generationCompleted(const QString &tjaContent);

    // 生成失败
    void generationFailed(const QString &errorMessage);

    // 状态更新
    void generationProgress(const QString &status);

private slots:
    void onReplyFinished(QNetworkReply *reply);

private:
    QNetworkAccessManager *m_network;
    QString m_apiKey;
    bool m_busy = false;
    QNetworkReply *m_activeReply = nullptr;

    QString buildSystemPrompt() const;
    QString buildUserPrompt(const QString &oggFileName,
                            const QString &genre,
                            const QString &difficulty,
                            int targetLevel,
                            int targetBpm,
                            bool withVariation,
                            bool withGogo,
                            bool withBranch,
                            double density) const;
    QString extractTJAFromResponse(const QString &responseText) const;
};

#endif // DEEPSEEKCLIENT_H