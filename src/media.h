#pragma once
#include <QHash>
#include <QObject>
#include <QPointer>
#include <QProcess>
#include <QSet>
#include <QStringList>
#include <QVariantMap>
#include <QVector>
#include <QtQml/qqml.h>

// Background analysis of the current file with FFmpeg / ffprobe, run as separate
// processes so playback never stalls:
//   - audio waveform (peak + RMS per 20 ms), streamed in while it decodes
//   - loudness (EBU R128 integrated, range, true peak)
//   - a 10x10 thumbnail sprite for timeline hover previews
//   - stream facts (bitrate, variable frame rate check)
//   - small thumbnails and durations for every file in the folder queue
// Results are cached on disk per file, keyed by path, size and modification time.
class Media : public QObject
{
    Q_OBJECT
    QML_ANONYMOUS // exposed to QML as the "Media" singleton instance in main.cpp
    Q_PROPERTY(QString file READ file NOTIFY fileChanged)
    Q_PROPERTY(bool waveformReady READ waveformReady NOTIFY waveformChanged)
    Q_PROPERTY(double waveformProgress READ waveformProgress NOTIFY waveformChanged)
    Q_PROPERTY(int peakRevision READ peakRevision NOTIFY waveformChanged)
    Q_PROPERTY(QVariantMap loudness READ loudness NOTIFY loudnessChanged)
    Q_PROPERTY(QVariantMap probe READ probe NOTIFY probeChanged)
    Q_PROPERTY(QString spriteUrl READ spriteUrl NOTIFY spriteChanged)
    Q_PROPERTY(double spriteInterval READ spriteInterval NOTIFY spriteChanged)
    Q_PROPERTY(int spriteCount READ spriteCount NOTIFY spriteChanged)
    Q_PROPERTY(int queueRevision READ queueRevision NOTIFY queueInfoChanged)
    Q_PROPERTY(QVariantList silences READ silences NOTIFY waveformChanged)

public:
    static constexpr int kBinsPerSecond = 50;
    static constexpr int kTileW = 192, kTileH = 108, kCols = 10, kRows = 10;

    static Media *instance();

    QString file() const { return m_file; }
    bool waveformReady() const { return m_waveDone; }
    double waveformProgress() const { return m_waveProgress; }
    int peakRevision() const { return m_peakRev; }
    QVariantMap loudness() const { return m_loudness; }
    QVariantMap probe() const { return m_probe; }
    QString spriteUrl() const { return m_spriteUrl; }
    double spriteInterval() const { return m_spriteInterval; }
    int spriteCount() const { return m_spriteCount; }
    int queueRevision() const { return m_queueRev; }
    QVariantList silences() const;

    // Peak (0..1) and RMS (0..1) per bin; bin i covers [i, i+1) / kBinsPerSecond seconds.
    const QVector<float> &peaks() const { return m_peak; }
    const QVector<float> &rms() const { return m_rms; }

    // Start analysing a file (cancels work on the previous one). duration may be 0 if unknown.
    Q_INVOKABLE void analyse(const QString &file, double duration, bool hasVideo);
    Q_INVOKABLE void setQueue(const QStringList &files);
    Q_INVOKABLE QString thumbFor(const QString &file) const;   // file:// URL or ""
    Q_INVOKABLE double durationFor(const QString &file) const; // seconds or -1
    // Start of the silent stretch containing t, as [start, end], or empty.
    Q_INVOKABLE QVariantList silenceAt(double t) const;

    static QString cacheDir();
    static QString cacheKey(const QString &file);
    static QString toolPath(const QString &name); // ffmpeg / ffprobe next to the exe, then PATH

signals:
    void fileChanged();
    void waveformChanged();
    void loudnessChanged();
    void probeChanged();
    void spriteChanged();
    void queueInfoChanged();

private:
    explicit Media(QObject *parent = nullptr);
    void stopAll();
    void startWaveform();
    void startLoudness();
    void startSprite();
    void startProbe();
    void computeSilences();
    void saveWaveCache();
    bool loadWaveCache();
    void pumpQueue();
    QProcess *spawn(const QString &tool, const QStringList &args);

    QString m_file;
    double m_duration = 0;
    bool m_hasVideo = false;
    int m_generation = 0;

    QVector<float> m_peak, m_rms;
    QByteArray m_pcmTail;
    bool m_waveDone = false;
    double m_waveProgress = 0;
    int m_peakRev = 0;
    QVector<QPair<double, double>> m_silences;

    QVariantMap m_loudness, m_probe;
    QString m_spriteUrl;
    double m_spriteInterval = 0;
    int m_spriteCount = 0;

    QList<QPointer<QProcess>> m_procs;

    // queue thumbnails
    QStringList m_queue, m_queueTodo;
    QHash<QString, QString> m_thumbs;
    QHash<QString, double> m_durations;
    QPointer<QProcess> m_queueProc;
    int m_queueRev = 0;
};
