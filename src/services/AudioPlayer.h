#pragma once

#include <QObject>
#include <QUrl>
#include <QString>
#include <QVariantList>
#include <QAudioDecoder>

class QMediaPlayer;
class QAudioOutput;

/**
 * @brief OGG/音频播放器，封装 QMediaPlayer + QAudioOutput
 *
 * 暴露给 QML 使用：
 *   - 属性: source, playing, position, duration, volume, waveformData
 *   - 方法: play(), pause(), stop(), loadFile(url)
 *   - 信号: 播放状态/进度变更
 */
class AudioPlayer : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QUrl source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(bool playing READ playing NOTIFY playingChanged)
    Q_PROPERTY(qint64 position READ position NOTIFY positionChanged)
    Q_PROPERTY(qint64 duration READ duration NOTIFY durationChanged)
    Q_PROPERTY(float volume READ volume WRITE setVolume NOTIFY volumeChanged)
    // 波形采样点数组 (0.0 ~ 1.0 归一化振幅，200 个点)，QML Canvas 可直接遍历
    Q_PROPERTY(QVariantList waveformData READ waveformData NOTIFY waveformDataChanged)
    // 检测到的 BPM（基于音频自相关分析，0 = 未检测）
    Q_PROPERTY(double detectedBpm READ detectedBpm NOTIFY detectedBpmChanged)

public:
    explicit AudioPlayer(QObject *parent = nullptr);
    ~AudioPlayer() override;

    QUrl source() const;
    void setSource(const QUrl &url);

    bool playing() const;

    qint64 position() const;
    qint64 duration() const;

    float volume() const;
    void setVolume(float vol);

    QVariantList waveformData() const;
    double detectedBpm() const;

public slots:
    void play();
    void pause();
    void stop();
    void loadFile(const QString &filePath);
    void setPosition(qint64 ms);

signals:
    void sourceChanged();
    void playingChanged();
    void positionChanged();
    void durationChanged();
    void volumeChanged();
    void waveformDataChanged();
    void detectedBpmChanged();

    void errorOccurred(const QString &message);
    void mediaLoaded();

private slots:
    void onBufferReady();
    void onDecoderFinished();

private:
    QMediaPlayer  *m_player;
    QAudioOutput  *m_audioOutput;
    QAudioDecoder *m_decoder;
    bool           m_playing;
    QVariantList   m_waveformData;
    QVector<qint16> m_samples;          // 波形解码临时采样缓冲区
    double m_detectedBpm = 0;           // 检测到的 BPM

    void extractWaveform(const QUrl &url);
    void detectBpm();                   // BPM 检测（基于 m_samples）
};