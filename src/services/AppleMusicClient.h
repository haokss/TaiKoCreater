#ifndef APPLEMUSICCLIENT_H
#define APPLEMUSICCLIENT_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QJsonObject>
#include <QJsonArray>
#include <QMap>
#include <QQueue>

class AppleMusicClient : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString developerToken READ developerToken WRITE setDeveloperToken NOTIFY tokenChanged)
    Q_PROPERTY(QString storefront READ storefront WRITE setStorefront NOTIFY storefrontChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)

public:
    explicit AppleMusicClient(QObject *parent = nullptr);

    QString developerToken() const { return m_developerToken; }
    void setDeveloperToken(const QString &token);
    QString storefront() const { return m_storefront; }
    void setStorefront(const QString &sf);
    bool busy() const { return m_busy; }

    /// 根据歌曲名 + 艺术家搜索歌曲，返回 songId（或空）
    Q_INVOKABLE void searchSong(const QString &title, const QString &artist = QString());

    /// 根据已知的 Apple Music song ID 获取封面 URL（已替换尺寸）
    Q_INVOKABLE void fetchArtworkById(const QString &songId);

    /// 根据歌曲名搜索并获取封面（searchSong + fetchArtworkById 的组合）
    Q_INVOKABLE void searchAndFetchArtwork(const QString &title, const QString &artist = QString());

    /// 下载封面图片到本地缓存，返回本地路径
    Q_INVOKABLE void downloadArtwork(const QString &artworkUrl, const QString &cacheKey);

    /// 批量获取多个歌曲的封面
    Q_INVOKABLE void fetchArtworks(const QJsonArray &songList);

    /// 一站式获取封面：搜索 → 下载，完成后发射 coverReady(title, localPath)
    Q_INVOKABLE void fetchCover(const QString &title);

signals:
    void tokenChanged();
    void storefrontChanged();
    void busyChanged();

    /// 搜索完成，返回 songId
    void searchCompleted(const QString &title, const QString &songId);

    /// 封面 URL 已就绪
    void artworkUrlReady(const QString &songId, const QString &artworkUrl);

    /// 封面已下载到本地
    void artworkDownloaded(const QString &cacheKey, const QString &localPath);

    /// 一站式封面获取完成
    void coverReady(const QString &title, const QString &localPath);

    /// 请求失败
    void requestFailed(const QString &errorMessage);

private:
    void onSearchReply(QNetworkReply *reply);
    void onFetchReply(QNetworkReply *reply, const QString &songId = QString());

    QNetworkAccessManager *m_network;
    QString m_developerToken;
    QString m_storefront = QStringLiteral("cn");
    bool m_busy = false;

    QNetworkRequest buildRequest(const QString &path) const;
    QString artworkUrlFromResponse(const QJsonObject &songData) const;
};

#endif // APPLEMUSICCLIENT_H