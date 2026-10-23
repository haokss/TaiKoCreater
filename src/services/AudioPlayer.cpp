#include "AudioPlayer.h"
#include <QMediaPlayer>
#include <QAudioOutput>
#include <QAudioDecoder>
#include <QAudioBuffer>
#include <QAudioFormat>
#include <QUrl>
#include <QFileInfo>
#include "../utils/Logger.h"
#include <cmath>
#include <QProcess>
#include <QCoreApplication>
#include <QDir>
#include <QFile>

static const int WAVEFORM_POINTS = 200;

AudioPlayer::AudioPlayer(QObject *parent)
    : QObject(parent), m_player(new QMediaPlayer(this)), m_audioOutput(new QAudioOutput(this)), m_decoder(nullptr), m_playing(false)
{
    m_player->setAudioOutput(m_audioOutput);
    m_audioOutput->setVolume(0.8f);

    connect(m_player, &QMediaPlayer::playbackStateChanged, this, [this](QMediaPlayer::PlaybackState state)
            {
        bool wasPlaying = m_playing;
        m_playing = (state == QMediaPlayer::PlayingState);
        if (wasPlaying != m_playing)
            emit playingChanged(); });

    connect(m_player, &QMediaPlayer::positionChanged, this, [this](qint64)
            { emit positionChanged(); });

    connect(m_player, &QMediaPlayer::durationChanged, this, [this](qint64)
            { emit durationChanged(); });

    connect(m_player, &QMediaPlayer::mediaStatusChanged, this, [this](QMediaPlayer::MediaStatus status)
            {
        if (status == QMediaPlayer::LoadedMedia) {
            emit mediaLoaded();
            extractWaveform(m_player->source());
        } });

    connect(m_player, &QMediaPlayer::errorOccurred, this, [this](QMediaPlayer::Error error, const QString &msg)
            {
        Q_UNUSED(error)
        emit errorOccurred(msg); });
}

AudioPlayer::~AudioPlayer() = default;

QUrl AudioPlayer::source() const { return m_player->source(); }
void AudioPlayer::setSource(const QUrl &url)
{
    if (m_player->source() != url)
    {
        m_player->setSource(url);
        emit sourceChanged();
    }
}
bool AudioPlayer::playing() const { return m_playing; }
qint64 AudioPlayer::position() const { return m_player->position(); }
qint64 AudioPlayer::duration() const { return m_player->duration(); }
float AudioPlayer::volume() const { return m_audioOutput->volume(); }
void AudioPlayer::setVolume(float vol)
{
    vol = qBound(0.0f, vol, 1.0f);
    if (!qFuzzyCompare(m_audioOutput->volume(), vol))
    {
        m_audioOutput->setVolume(vol);
        emit volumeChanged();
    }
}
QVariantList AudioPlayer::waveformData() const { return m_waveformData; }
double AudioPlayer::detectedBpm() const { return m_detectedBpm; }
void AudioPlayer::play() { m_player->play(); }
void AudioPlayer::pause() { m_player->pause(); }
void AudioPlayer::stop() { m_player->stop(); }
void AudioPlayer::loadFile(const QString &filePath)
{
    if (filePath.startsWith("file:///"))
        setSource(QUrl(filePath));
    else
        setSource(QUrl::fromLocalFile(filePath));
}
void AudioPlayer::setPosition(qint64 ms)
{
    if (m_player->duration() > 0)
        m_player->setPosition(qBound<qint64>(0, ms, m_player->duration()));
}

// ── 波形提取 ──
void AudioPlayer::extractWaveform(const QUrl &url)
{
    if (url.isEmpty())
        return;
    if (m_decoder)
    {
        m_decoder->deleteLater();
        m_decoder = nullptr;
    }

    m_decoder = new QAudioDecoder(this);
    m_samples.clear();

    // Qt 6.10.1 signals: bufferReady() + read(), finished()
    connect(m_decoder, &QAudioDecoder::bufferReady, this, &AudioPlayer::onBufferReady);
    connect(m_decoder, &QAudioDecoder::finished, this, &AudioPlayer::onDecoderFinished);

    QString localPath = url.toLocalFile();
    Logger::log("AudioPlayer", QStringLiteral("解码波形 path=") + localPath);
    m_decoder->setSource(localPath);
    m_decoder->start();
}

// 从 QAudioBuffer 提取样本值，归一化到 0.0~1.0
static float sampleToAmplitude(const QAudioBuffer &buf, int frame, int channelCount)
{
    auto fmt = buf.format().sampleFormat();
    switch (fmt) {
    case QAudioFormat::Int16: {
        auto d = buf.constData<qint16>();
        if (!d) return 0;
        return qAbs(d[frame * channelCount]) / 32768.0f;
    }
    case QAudioFormat::Int32: {
        auto d = buf.constData<qint32>();
        if (!d) return 0;
        return qAbs(d[frame * channelCount]) / 2147483648.0f;
    }
    case QAudioFormat::Float: {
        auto d = buf.constData<float>();
        if (!d) return 0;
        return qMin(qAbs(d[frame * channelCount]), 1.0f);
    }
    default:
        return 0;
    }
}

void AudioPlayer::onBufferReady()
{
    if (!m_decoder)
        return;
    QAudioBuffer buf = m_decoder->read();
    if (!buf.isValid()) {
        Logger::log("AudioPlayer", "bufferReady 但 buf 无效");
        return;
    }
    int channels = buf.format().channelCount();
    int frameCount = buf.frameCount();
    auto fmt = buf.format().sampleFormat();
    Logger::log("AudioPlayer", QStringLiteral("收到 buffer: %1 帧, %2 声道, 格式=%3")
                                .arg(frameCount).arg(channels)
                                .arg(fmt == QAudioFormat::Int16 ? "Int16" :
                                     fmt == QAudioFormat::Int32 ? "Int32" :
                                     fmt == QAudioFormat::Float ? "Float" : "Unknown"));
    for (int f = 0; f < frameCount; ++f) {
        float amp = sampleToAmplitude(buf, f, channels);
        m_samples.append(static_cast<qint16>(qMin(amp, 1.0f) * 32767.0f));
    }
}

void AudioPlayer::onDecoderFinished()
{
    m_waveformData.clear();

    if (m_samples.isEmpty())
    {
        Logger::log("AudioPlayer", "收集到0个样本，用空波形");
        for (int i = 0; i < WAVEFORM_POINTS; ++i)
            m_waveformData.append(0.0);
    }
    else
    {
        Logger::log("AudioPlayer", QStringLiteral("收集到%1个样本").arg(m_samples.size()));

        int bucketSize = qMax(1, static_cast<int>(m_samples.size()) / WAVEFORM_POINTS);
        qint16 globalMax = 1;
        for (auto s : m_samples)
            globalMax = qMax(globalMax, static_cast<qint16>(qAbs(s)));

        for (int i = 0; i < WAVEFORM_POINTS; ++i)
        {
            int start = i * bucketSize;
            int end = qMin(start + bucketSize, static_cast<int>(m_samples.size()));
            qint16 peak = 0;
            for (int j = start; j < end; ++j)
                peak = qMax(peak, static_cast<qint16>(qAbs(m_samples[j])));
            m_waveformData.append(static_cast<double>(peak) / globalMax);
        }
        Logger::log("AudioPlayer", QStringLiteral("波形完成，%1个点").arg(m_waveformData.size()));
    }

    if (m_decoder)
    {
        m_decoder->deleteLater();
        m_decoder = nullptr;
    }
    detectBpm();  // 注意：必须在 m_samples.clear() 之前调用
    m_samples.clear();
    emit waveformDataChanged();
}

// ── BPM 检测（通过 aubio Python 脚本） ──
void AudioPlayer::detectBpm()
{
    QString filePath = m_player->source().toLocalFile();
    if (filePath.isEmpty()) return;

    // 查找脚本路径（优先 exe 同目录的 tools/，其次项目源码目录）
    QString scriptDir = QCoreApplication::applicationDirPath() + "/tools";
    if (!QDir(scriptDir).exists())
        scriptDir = QCoreApplication::applicationDirPath() + "/../tools";
    QString scriptPath = scriptDir + "/bpm_detect.py";
    if (!QFile::exists(scriptPath)) {
        Logger::log("AudioPlayer", "BPM脚本不存在: " + scriptPath);
        return;
    }

    Logger::log("AudioPlayer", QStringLiteral("启动librosa BPM检测: %1").arg(filePath));

    QProcess *process = new QProcess(this);
    process->setWorkingDirectory(scriptDir);
    connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this, process](int exitCode, QProcess::ExitStatus) {
                if (exitCode != 0) {
                    QString err = QString::fromUtf8(process->readAllStandardError()).trimmed();
                    Logger::log("AudioPlayer", "librosa进程错误: " + err);
                } else {
                    QString output = QString::fromUtf8(process->readAllStandardOutput()).trimmed();
                    // 解析 "BPM:150.5"
                    if (output.startsWith("BPM:")) {
                        bool ok = false;
                        double bpm = output.mid(4).toDouble(&ok);
                        if (ok && bpm > 0) {
                            m_detectedBpm = qRound(bpm * 10.0) / 10.0;
                            Logger::log("AudioPlayer", QStringLiteral("librosa BPM: %1").arg(m_detectedBpm));
                            emit detectedBpmChanged();
                        }
                    }
                }
                process->deleteLater();
            });
    process->start("python", QStringList() << scriptPath << filePath);
}
