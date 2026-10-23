#include "AppleMusicClient.h"
#include "../utils/Logger.h"
#include <QJsonDocument>
#include <QNetworkRequest>
#include <QUrl>
#include <QUrlQuery>
#include <QDir>
#include <QFile>
#include <QStandardPaths>
#include <QCryptographicHash>

static const QString API_BASE = QStringLiteral("https://api.music.apple.com/v1");

AppleMusicClient::AppleMusicClient(QObject *parent)
    : QObject(parent)
    , m_network(new QNetworkAccessManager(this))
{
}

void AppleMusicClient::setDeveloperToken(const QString &token)
{
    if (m_developerToken != token) {
        m_developerToken = token;
        emit tokenChanged();
    }
}

void AppleMusicClient::setStorefront(const QString &sf)
{
    if (m_storefront != sf) {
        m_storefront = sf;
        emit storefrontChanged();
    }
}

QNetworkRequest AppleMusicClient::buildRequest(const QString &path) const
{
    QUrl url(API_BASE + path);
    QNetworkRequest req(url);
    req.setRawHeader("Authorization", ("Bearer " + m_developerToken).toUtf8());
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    return req;
}

// ── 搜索歌曲（GET /catalog/{storefront}/search?term=...&limit=1&types=songs） ──
void AppleMusicClient::searchSong(const QString &title, const QString &artist)
{
    if (m_developerToken.isEmpty()) {
        emit requestFailed("Apple Music Developer Token 未设置");
        return;
    }

    QString term = title.simplified();
    if (!artist.isEmpty()) {
        term += " " + artist.simplified();
    }

    QUrlQuery query;
    query.addQueryItem("term", term);
    query.addQueryItem("limit", "3");
    query.addQueryItem("types", "songs");

    QString path = QStringLiteral("/catalog/%1/search").arg(m_storefront);
    QUrl url(API_BASE + path);
    url.setQuery(query);

    QNetworkRequest req(url);
    req.setRawHeader("Authorization", ("Bearer " + m_developerToken).toUtf8());
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");

    m_busy = true;
    emit busyChanged();
    LOG_TAG("Cover", "搜索歌曲: " + term);

    QNetworkReply *reply = m_network->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        onSearchReply(reply);
    });
}

void AppleMusicClient::onSearchReply(QNetworkReply *reply)
{
    reply->deleteLater();
    m_busy = false;
    emit busyChanged();

    if (reply->error() != QNetworkReply::NoError) {
        QString err = reply->errorString();
        LOG_TAG("Cover", "搜索失败: " + err);
        emit requestFailed("搜索失败: " + err);
        return;
    }

    QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
    QJsonObject root = doc.object();
    QJsonArray data = root.value("results").toObject()
                          .value("songs").toObject()
                          .value("data").toArray();

    if (data.isEmpty()) {
        LOG_TAG("Cover", "搜索无结果");
        emit searchCompleted(QString(), QString());
        return;
    }

    QJsonObject song = data.first().toObject();
    QString songId = song.value("id").toString();
    QString songTitle = song.value("attributes").toObject().value("name").toString();

    LOG_TAG("Cover", "找到歌曲: " + songTitle + " [" + songId + "]");
    emit searchCompleted(songTitle, songId);
}

// ── 根据 songId 获取歌曲详情（GET /catalog/{storefront}/songs/{id}） ──
void AppleMusicClient::fetchArtworkById(const QString &songId)
{
    if (m_developerToken.isEmpty()) {
        emit requestFailed("Apple Music Developer Token 未设置");
        return;
    }
    if (songId.isEmpty()) {
        emit requestFailed("songId 为空");
        return;
    }

    QString path = QStringLiteral("/catalog/%1/songs/%2").arg(m_storefront, songId);

    m_busy = true;
    emit busyChanged();
    LOG_TAG("Cover", "获取歌曲详情: " + songId);

    QNetworkReply *reply = m_network->get(buildRequest(path));
    connect(reply, &QNetworkReply::finished, this, [this, reply, songId]() {
        onFetchReply(reply, songId);
    });
}

void AppleMusicClient::onFetchReply(QNetworkReply *reply, const QString &songId)
{
    reply->deleteLater();
    m_busy = false;
    emit busyChanged();

    if (reply->error() != QNetworkReply::NoError) {
        QString err = reply->errorString();
        LOG_TAG("Cover", "获取详情失败: " + err);
        emit requestFailed("获取歌曲详情失败: " + err);
        return;
    }

    QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
    QJsonArray data = doc.object().value("data").toArray();

    if (data.isEmpty()) {
        LOG_TAG("Cover", "未找到歌曲详情: " + songId);
        emit requestFailed("未找到歌曲: " + songId);
        return;
    }

    QString artworkUrl = artworkUrlFromResponse(data.first().toObject());
    LOG_TAG("Cover", "封面URL已找到: " + songId);
    emit artworkUrlReady(songId, artworkUrl);
}

// ── 解析 artwork URL，替换尺寸为 3000x3000 高清版 ──
QString AppleMusicClient::artworkUrlFromResponse(const QJsonObject &songData) const
{
    QJsonObject attrs = songData.value("attributes").toObject();
    QJsonObject artwork = attrs.value("artwork").toObject();
    QString urlTemplate = artwork.value("url").toString();

    if (urlTemplate.isEmpty())
        return QString();

    urlTemplate.replace("{w}", "3000");
    urlTemplate.replace("{h}", "3000");

    return urlTemplate;
}

// ── 组合接口：搜索 → 获取封面 URL ──
void AppleMusicClient::searchAndFetchArtwork(const QString &title, const QString &artist)
{
    if (m_developerToken.isEmpty()) {
        emit requestFailed("Apple Music Developer Token 未设置");
        return;
    }
    if (title.isEmpty()) {
        emit requestFailed("歌曲名不能为空");
        return;
    }

    m_busy = true;
    emit busyChanged();

    QString term = title.simplified();
    if (!artist.isEmpty())
        term += " " + artist.simplified();

    QUrlQuery query;
    query.addQueryItem("term", term);
    query.addQueryItem("limit", "3");
    query.addQueryItem("types", "songs");

    QString path = QStringLiteral("/catalog/%1/search").arg(m_storefront);
    QUrl url(API_BASE + path);
    url.setQuery(query);

    QNetworkRequest req(url);
    req.setRawHeader("Authorization", ("Bearer " + m_developerToken).toUtf8());
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");

    LOG_TAG("Cover", "搜索并获取封面: " + term);

    QNetworkReply *reply = m_network->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        m_busy = false;
        emit busyChanged();

        if (reply->error() != QNetworkReply::NoError) {
            LOG_TAG("Cover", "搜索失败: " + reply->errorString());
            emit requestFailed("搜索失败: " + reply->errorString());
            return;
        }

        QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        QJsonArray data = doc.object().value("results").toObject()
                              .value("songs").toObject()
                              .value("data").toArray();

        if (data.isEmpty()) {
            LOG_TAG("Cover", "搜索无结果");
            emit artworkUrlReady(QString(), QString());
            return;
        }

        QJsonObject song = data.first().toObject();
        QString songId = song.value("id").toString();
        QString artworkUrl = artworkUrlFromResponse(song);
        LOG_TAG("Cover", "封面URL已找到: " + songId);
        emit artworkUrlReady(songId, artworkUrl);
    });
}

// ── 下载封面 ──
void AppleMusicClient::downloadArtwork(const QString &artworkUrl, const QString &cacheKey)
{
    if (artworkUrl.isEmpty()) {
        emit requestFailed("artworkUrl 为空");
        return;
    }

    QUrl url(artworkUrl);

    QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation)
                       + "/covers";
    QDir().mkpath(cacheDir);

    QString safeKey = cacheKey.isEmpty()
        ? QString::fromUtf8(QCryptographicHash::hash(
              artworkUrl.toUtf8(), QCryptographicHash::Md5).toHex())
        : cacheKey;

    QString localPath = cacheDir + "/" + safeKey + ".jpg";

    if (QFile::exists(localPath)) {
        LOG_TAG("Cover", "封面缓存命中: " + safeKey);
        emit artworkDownloaded(cacheKey, localPath);
        return;
    }

    m_busy = true;
    emit busyChanged();
    LOG_TAG("Cover", "下载封面: " + artworkUrl);

    QNetworkRequest req(url);
    QNetworkReply *reply = m_network->get(req);

    connect(reply, &QNetworkReply::finished, this, [this, reply, localPath, cacheKey]() {
        reply->deleteLater();
        m_busy = false;
        emit busyChanged();

        if (reply->error() != QNetworkReply::NoError) {
            LOG_TAG("Cover", "下载封面失败: " + reply->errorString());
            emit requestFailed("下载封面失败: " + reply->errorString());
            return;
        }

        QFile file(localPath);
        if (file.open(QIODevice::WriteOnly)) {
            file.write(reply->readAll());
            file.close();
            LOG_TAG("Cover", "封面已保存: " + localPath);
            emit artworkDownloaded(cacheKey, localPath);
        } else {
            LOG_TAG("Cover", "无法保存封面到: " + localPath);
            emit requestFailed("无法保存封面到: " + localPath);
        }
    });
}

// ── 批量获取封面 ──
void AppleMusicClient::fetchArtworks(const QJsonArray &songList)
{
    if (songList.isEmpty()) return;

    for (const QJsonValue &val : songList) {
        QJsonObject item = val.toObject();
        QString title = item.value("title").toString();
        QString artist = item.value("artist").toString();

        if (!title.isEmpty()) {
            searchAndFetchArtwork(title, artist);
        }
    }
}

// ── 一站式封面获取 ──
void AppleMusicClient::fetchCover(const QString &title)
{
    if (m_developerToken.isEmpty()) {
        LOG_TAG("Cover", "Token未设置，跳过封面请求");
        emit coverReady(title, QString());
        return;
    }
    if (title.isEmpty()) {
        emit coverReady(title, QString());
        return;
    }

    QString cacheKey = QString::fromUtf8(
        QCryptographicHash::hash(title.toUtf8(), QCryptographicHash::Md5).toHex());

    QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/covers";
    QDir().mkpath(cacheDir);
    QString localPath = cacheDir + "/" + cacheKey + ".jpg";
    if (QFile::exists(localPath)) {
        LOG_TAG("Cover", "缓存命中: " + title);
        emit coverReady(title, localPath);
        return;
    }

    m_busy = true;
    emit busyChanged();
    LOG_TAG("Cover", "请求封面: " + title);

    QString term = title.simplified();
    QUrlQuery query;
    query.addQueryItem("term", term);
    query.addQueryItem("limit", "3");
    query.addQueryItem("types", "songs");

    QString path = QStringLiteral("/catalog/%1/search").arg(m_storefront);
    QUrl url(API_BASE + path);
    url.setQuery(query);

    QNetworkRequest req(url);
    req.setRawHeader("Authorization", ("Bearer " + m_developerToken).toUtf8());
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");

    QNetworkReply *reply = m_network->get(req);

    connect(reply, &QNetworkReply::finished, this, [this, reply, title, localPath]() {
        reply->deleteLater();
        m_busy = false;
        emit busyChanged();

        if (reply->error() != QNetworkReply::NoError) {
            LOG_TAG("Cover", "搜索失败: " + title + " - " + reply->errorString());
            emit coverReady(title, QString());
            return;
        }

        QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        QJsonArray data = doc.object().value("results").toObject()
                              .value("songs").toObject()
                              .value("data").toArray();

        if (data.isEmpty()) {
            LOG_TAG("Cover", "搜索无结果: " + title);
            emit coverReady(title, QString());
            return;
        }

        QString artworkUrl = artworkUrlFromResponse(data.first().toObject());
        if (artworkUrl.isEmpty()) {
            LOG_TAG("Cover", "无封面URL: " + title);
            emit coverReady(title, QString());
            return;
        }

        LOG_TAG("Cover", "下载封面: " + title);
        QNetworkReply *dlReply = m_network->get(QNetworkRequest(QUrl(artworkUrl)));
        connect(dlReply, &QNetworkReply::finished, this, [this, dlReply, title, localPath]() {
            dlReply->deleteLater();
            m_busy = false;
            emit busyChanged();

            if (dlReply->error() != QNetworkReply::NoError) {
                LOG_TAG("Cover", "下载失败: " + title + " - " + dlReply->errorString());
                emit coverReady(title, QString());
                return;
            }

            QFile file(localPath);
            if (file.open(QIODevice::WriteOnly)) {
                file.write(dlReply->readAll());
                file.close();
                LOG_TAG("Cover", "封面已下载: " + title + " -> " + localPath);
                emit coverReady(title, localPath);
            } else {
                LOG_TAG("Cover", "保存失败: " + title);
                emit coverReady(title, QString());
            }
        });
    });
}