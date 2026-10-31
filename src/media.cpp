#include "media.h"
#include "folderqueue.h"

#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDataStream>
#include <QDir>
#include <QElapsedTimer>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QSaveFile>
#include <QStandardPaths>
#include <QUrl>
#include <algorithm>
#include <cmath>

namespace {
constexpr int kSampleRate = 8000;                                // decode rate for the waveform
constexpr int kSamplesPerBin = kSampleRate / Media::kBinsPerSecond; // 160
constexpr quint32 kWaveMagic = 0x534c5731;                        // "SLW1"

double parseRate(const QString &r)
{
    const QStringList p = r.split(QLatin1Char('/'));
    if (p.size() == 2 && p[1].toDouble() > 0)
        return p[0].toDouble() / p[1].toDouble();
    return r.toDouble();
}

bool isAudioFile(const QString &f)
{
    static const QSet<QString> audio = { QStringLiteral("mp3"), QStringLiteral("wav"), QStringLiteral("flac"), QStringLiteral("m4a"),
                                         QStringLiteral("aac"), QStringLiteral("ogg"), QStringLiteral("opus"), QStringLiteral("aiff"),
                                         QStringLiteral("aif"), QStringLiteral("wma"), QStringLiteral("alac"), QStringLiteral("ac3") };
    return audio.contains(QFileInfo(f).suffix().toLower());
}
} // namespace

Media::Media(QObject *parent) : QObject(parent) {}

Media *Media::instance()
{
    static Media *m = new Media();
    return m;
}

QString Media::cacheDir()
{
    static const QString d = [] {
        QString p = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
        if (p.isEmpty())
            p = QDir::tempPath() + QStringLiteral("/Slate");
        p += QStringLiteral("/analysis");
        QDir().mkpath(p);
        return p;
    }();
    return d;
}

QString Media::cacheKey(const QString &file)
{
    const QFileInfo fi(file);
    const QByteArray id = fi.absoluteFilePath().toUtf8() + '|' + QByteArray::number(fi.size()) + '|'
        + QByteArray::number(fi.lastModified().toMSecsSinceEpoch());
    return QString::fromLatin1(QCryptographicHash::hash(id, QCryptographicHash::Sha1).toHex().left(24));
}

QString Media::toolPath(const QString &name)
{
#ifdef Q_OS_WIN
    const QString exe = name + QStringLiteral(".exe");
#else
    const QString exe = name;
#endif
    const QString local = QCoreApplication::applicationDirPath() + QLatin1Char('/') + exe;
    if (QFileInfo::exists(local))
        return local;
    return QStandardPaths::findExecutable(name);
}

QProcess *Media::spawn(const QString &tool, const QStringList &args)
{
    const QString exe = toolPath(tool);
    if (exe.isEmpty())
        return nullptr;
    auto *p = new QProcess(this);
    p->setProgram(exe);
    p->setArguments(args);
    connect(p, &QProcess::finished, p, &QObject::deleteLater);
    connect(p, &QProcess::errorOccurred, p, [p](QProcess::ProcessError e) { if (e == QProcess::FailedToStart) p->deleteLater(); });
    m_procs << p;
    return p;
}

void Media::stopAll()
{
    for (const QPointer<QProcess> &p : std::as_const(m_procs)) {
        if (p) {
            p->disconnect(this);
            p->kill();
        }
    }
    m_procs.clear();
}

void Media::analyse(const QString &file, double duration, bool hasVideo)
{
    if (file == m_file && qAbs(duration - m_duration) < 0.5 && hasVideo == m_hasVideo)
        return;
    const bool sameFile = file == m_file;
    if (sameFile) {
        // Same file, better metadata (duration known now): only start what was skipped.
        const bool needSprite = hasVideo && !m_hasVideo;
        m_duration = duration;
        m_hasVideo = hasVideo;
        if (needSprite || (m_hasVideo && m_spriteUrl.isEmpty() && duration > 0))
            startSprite();
        return;
    }
    stopAll();
    ++m_generation;
    m_file = file;
    m_duration = duration;
    m_hasVideo = hasVideo;
    m_peak.clear();
    m_rms.clear();
    m_pcmTail.clear();
    m_silences.clear();
    m_waveDone = false;
    m_waveProgress = 0;
    ++m_peakRev;
    m_loudness.clear();
    m_probe.clear();
    m_spriteUrl.clear();
    m_spriteInterval = 0;
    m_spriteCount = 0;
    emit fileChanged();
    emit waveformChanged();
    emit loudnessChanged();
    emit probeChanged();
    emit spriteChanged();

    if (!QFileInfo(file).isFile())
        return; // URLs: nothing to analyse locally

    if (!loadWaveCache())
        startWaveform();
    startProbe();
    if (m_hasVideo && m_duration > 0)
        startSprite();

    QFile lc(cacheDir() + QLatin1Char('/') + cacheKey(file) + QStringLiteral(".loudness.json"));
    if (lc.open(QIODevice::ReadOnly)) {
        m_loudness = QJsonDocument::fromJson(lc.readAll()).object().toVariantMap();
        emit loudnessChanged();
    }
}

// ---- waveform ---------------------------------------------------------------
void Media::startWaveform()
{
    QProcess *p = spawn(QStringLiteral("ffmpeg"), { QStringLiteral("-v"), QStringLiteral("error"), QStringLiteral("-nostdin"),
                                                   QStringLiteral("-i"), m_file, QStringLiteral("-map"), QStringLiteral("0:a:0"),
                                                   QStringLiteral("-ac"), QStringLiteral("1"), QStringLiteral("-ar"), QString::number(kSampleRate),
                                                   QStringLiteral("-f"), QStringLiteral("s16le"), QStringLiteral("-") });
    if (!p) {
        m_waveDone = true;
        emit waveformChanged();
        return;
    }
    const int gen = m_generation;
    auto *timer = new QElapsedTimer;
    timer->start();
    connect(p, &QProcess::readyReadStandardOutput, this, [this, p, gen, timer] {
        if (gen != m_generation) return;
        m_pcmTail += p->readAllStandardOutput();
        const int binBytes = kSamplesPerBin * 2;
        const int bins = m_pcmTail.size() / binBytes;
        const auto *s = reinterpret_cast<const qint16 *>(m_pcmTail.constData());
        for (int b = 0; b < bins; ++b) {
            int pk = 0;
            double sum = 0;
            for (int i = 0; i < kSamplesPerBin; ++i) {
                const int v = s[b * kSamplesPerBin + i];
                pk = qMax(pk, qAbs(v));
                sum += double(v) * v;
            }
            m_peak << float(pk / 32768.0);
            m_rms << float(std::sqrt(sum / kSamplesPerBin) / 32768.0);
        }
        m_pcmTail.remove(0, bins * binBytes);
        if (timer->elapsed() > 200) {
            timer->restart();
            m_waveProgress = m_duration > 0 ? qMin(1.0, m_peak.size() / (m_duration * kBinsPerSecond)) : 0;
            ++m_peakRev;
            emit waveformChanged();
        }
    });
    connect(p, &QProcess::finished, this, [this, gen, timer](int code) {
        delete timer;
        if (gen != m_generation) return;
        m_waveDone = true;
        m_waveProgress = 1;
        ++m_peakRev;
        computeSilences();
        if (code == 0 && !m_peak.isEmpty())
            saveWaveCache();
        emit waveformChanged();
        if (!m_peak.isEmpty())
            startLoudness();
    });
    p->start();
}

void Media::computeSilences()
{
    // Quiet stretches (below about -40 dBFS RMS) of at least 0.8 s, trimmed so speech isn't clipped.
    m_silences.clear();
    const int minBins = int(0.8 * kBinsPerSecond);
    const double pad = 0.15;
    int start = -1;
    for (int i = 0; i <= m_rms.size(); ++i) {
        const bool quiet = i < m_rms.size() && m_rms[i] < 0.01f && m_peak[i] < 0.05f;
        if (quiet && start < 0)
            start = i;
        if (!quiet && start >= 0) {
            if (i - start >= minBins) {
                const double a = double(start) / kBinsPerSecond + pad, b = double(i) / kBinsPerSecond - pad;
                if (b - a > 0.4)
                    m_silences.append({ a, b });
            }
            start = -1;
        }
    }
}

QVariantList Media::silences() const
{
    QVariantList l;
    for (const auto &s : m_silences)
        l << QVariant(QVariantList{ s.first, s.second });
    return l;
}

QVariantList Media::silenceAt(double t) const
{
    auto it = std::upper_bound(m_silences.cbegin(), m_silences.cend(), t, [](double v, const QPair<double, double> &s) { return v < s.first; });
    if (it == m_silences.cbegin())
        return {};
    --it;
    if (t >= it->first && t < it->second)
        return { it->first, it->second };
    return {};
}

void Media::saveWaveCache()
{
    QSaveFile f(cacheDir() + QLatin1Char('/') + cacheKey(m_file) + QStringLiteral(".wave"));
    if (!f.open(QIODevice::WriteOnly)) return;
    QDataStream ds(&f);
    ds << kWaveMagic << quint32(m_peak.size());
    f.write(reinterpret_cast<const char *>(m_peak.constData()), m_peak.size() * sizeof(float));
    f.write(reinterpret_cast<const char *>(m_rms.constData()), m_rms.size() * sizeof(float));
    f.commit();
}

bool Media::loadWaveCache()
{
    QFile f(cacheDir() + QLatin1Char('/') + cacheKey(m_file) + QStringLiteral(".wave"));
    if (!f.open(QIODevice::ReadOnly)) return false;
    QDataStream ds(&f);
    quint32 magic = 0, n = 0;
    ds >> magic >> n;
    if (magic != kWaveMagic || n == 0 || f.size() != qint64(8 + 2 * n * sizeof(float)))
        return false;
    m_peak.resize(int(n));
    m_rms.resize(int(n));
    f.read(reinterpret_cast<char *>(m_peak.data()), n * sizeof(float));
    f.read(reinterpret_cast<char *>(m_rms.data()), n * sizeof(float));
    m_waveDone = true;
    m_waveProgress = 1;
    ++m_peakRev;
    computeSilences();
    emit waveformChanged();
    if (m_loudness.isEmpty())
        QMetaObject::invokeMethod(this, [this, gen = m_generation] { if (gen == m_generation && m_loudness.isEmpty()) startLoudness(); }, Qt::QueuedConnection);
    return true;
}

// ---- loudness ---------------------------------------------------------------
void Media::startLoudness()
{
    QFile lc(cacheDir() + QLatin1Char('/') + cacheKey(m_file) + QStringLiteral(".loudness.json"));
    if (lc.exists()) return;
    QProcess *p = spawn(QStringLiteral("ffmpeg"), { QStringLiteral("-nostats"), QStringLiteral("-nostdin"), QStringLiteral("-hide_banner"),
                                                   QStringLiteral("-i"), m_file, QStringLiteral("-map"), QStringLiteral("0:a:0"),
                                                   QStringLiteral("-af"), QStringLiteral("ebur128=peak=true"), QStringLiteral("-f"), QStringLiteral("null"), QStringLiteral("-") });
    if (!p) return;
    const int gen = m_generation;
    m_loudness = { { QStringLiteral("measuring"), true } };
    emit loudnessChanged();
    connect(p, &QProcess::finished, this, [this, p, gen](int code) {
        if (gen != m_generation) return;
        const QString err = QString::fromUtf8(p->readAllStandardError());
        const int sum = err.lastIndexOf(QStringLiteral("Summary:"));
        QVariantMap m;
        if (code == 0 && sum >= 0) {
            const QString s = err.mid(sum);
            auto grab = [&](const char *re) {
                const auto mt = QRegularExpression(QString::fromLatin1(re)).match(s);
                return mt.hasMatch() ? mt.captured(1).toDouble() : qQNaN();
            };
            const double i = grab(R"(I:\s+(-?[\d.]+|-inf)\s+LUFS)"), lra = grab(R"(LRA:\s+(-?[\d.]+)\s+LU)"), tp = grab(R"(Peak:\s+(-?[\d.]+|-inf)\s+dBFS)");
            if (!std::isnan(i)) m.insert(QStringLiteral("integrated"), i);
            if (!std::isnan(lra)) m.insert(QStringLiteral("range"), lra);
            if (!std::isnan(tp)) m.insert(QStringLiteral("truePeak"), tp);
            QSaveFile f(cacheDir() + QLatin1Char('/') + cacheKey(m_file) + QStringLiteral(".loudness.json"));
            if (!m.isEmpty() && f.open(QIODevice::WriteOnly)) {
                f.write(QJsonDocument(QJsonObject::fromVariantMap(m)).toJson(QJsonDocument::Compact));
                f.commit();
            }
        }
        m_loudness = m;
        emit loudnessChanged();
    });
    p->start();
}

// ---- thumbnail sprite -----------------------------------------------------------
void Media::startSprite()
{
    if (m_duration <= 0 || !QFileInfo(m_file).isFile()) return;
    const double interval = qMax(m_duration / (kCols * kRows), 0.2);
    const int count = qMin(kCols * kRows, int(std::ceil(m_duration / interval)));
    const QString out = cacheDir() + QLatin1Char('/') + cacheKey(m_file) + QStringLiteral(".sprite.jpg");
    auto publish = [this, out, interval, count] {
        m_spriteUrl = QUrl::fromLocalFile(out).toString();
        m_spriteInterval = interval;
        m_spriteCount = count;
        emit spriteChanged();
    };
    if (QFileInfo(out).size() > 0) {
        publish();
        return;
    }
    QStringList args = { QStringLiteral("-v"), QStringLiteral("error"), QStringLiteral("-nostdin"), QStringLiteral("-y") };
    if (m_duration > 300) // long files: decode keyframes only, much faster
        args << QStringLiteral("-skip_frame") << QStringLiteral("nokey");
    const QString vf = QStringLiteral("fps=1/%1,scale=%2:%3:force_original_aspect_ratio=decrease,pad=%2:%3:-1:-1:color=black,tile=%4x%5")
                           .arg(interval, 0, 'f', 4).arg(kTileW).arg(kTileH).arg(kCols).arg(kRows);
    args << QStringLiteral("-i") << m_file << QStringLiteral("-an") << QStringLiteral("-sn") << QStringLiteral("-vf") << vf
         << QStringLiteral("-frames:v") << QStringLiteral("1") << QStringLiteral("-q:v") << QStringLiteral("5") << out;
    QProcess *p = spawn(QStringLiteral("ffmpeg"), args);
    if (!p) return;
    const int gen = m_generation;
    connect(p, &QProcess::finished, this, [this, gen, out, publish](int code) {
        if (gen != m_generation) return;
        if (code == 0 && QFileInfo(out).size() > 0)
            publish();
    });
    p->start();
}

// ---- stream facts ---------------------------------------------------------------
void Media::startProbe()
{
    QFile pc(cacheDir() + QLatin1Char('/') + cacheKey(m_file) + QStringLiteral(".probe.json"));
    if (pc.open(QIODevice::ReadOnly)) {
        m_probe = QJsonDocument::fromJson(pc.readAll()).object().toVariantMap();
        emit probeChanged();
        return;
    }
    QProcess *p = spawn(QStringLiteral("ffprobe"), { QStringLiteral("-v"), QStringLiteral("error"), QStringLiteral("-print_format"), QStringLiteral("json"),
                                                    QStringLiteral("-show_format"), QStringLiteral("-show_streams"), m_file });
    if (!p) return;
    const int gen = m_generation;
    connect(p, &QProcess::finished, this, [this, p, gen](int code) {
        if (gen != m_generation || code != 0) return;
        const QJsonObject root = QJsonDocument::fromJson(p->readAllStandardOutput()).object();
        QVariantMap m;
        const QJsonObject fmt = root.value(QStringLiteral("format")).toObject();
        m.insert(QStringLiteral("container"), fmt.value(QStringLiteral("format_long_name")).toString());
        m.insert(QStringLiteral("bitrate"), fmt.value(QStringLiteral("bit_rate")).toString().toDouble());
        m.insert(QStringLiteral("size"), fmt.value(QStringLiteral("size")).toString().toDouble());
        bool video = false, audio = false;
        for (const QJsonValue &v : root.value(QStringLiteral("streams")).toArray()) {
            const QJsonObject s = v.toObject();
            const QString type = s.value(QStringLiteral("codec_type")).toString();
            const QJsonObject disp = s.value(QStringLiteral("disposition")).toObject();
            if (type == QLatin1String("video") && !video && disp.value(QStringLiteral("attached_pic")).toInt() == 0) {
                video = true;
                m.insert(QStringLiteral("videoCodec"), s.value(QStringLiteral("codec_name")).toString());
                m.insert(QStringLiteral("videoProfile"), s.value(QStringLiteral("profile")).toString());
                m.insert(QStringLiteral("width"), s.value(QStringLiteral("width")).toInt());
                m.insert(QStringLiteral("height"), s.value(QStringLiteral("height")).toInt());
                m.insert(QStringLiteral("frameRate"), parseRate(s.value(QStringLiteral("r_frame_rate")).toString()));
                m.insert(QStringLiteral("avgFrameRate"), parseRate(s.value(QStringLiteral("avg_frame_rate")).toString()));
                m.insert(QStringLiteral("videoBitrate"), s.value(QStringLiteral("bit_rate")).toString().toDouble());
                m.insert(QStringLiteral("pixelFormat"), s.value(QStringLiteral("pix_fmt")).toString());
                m.insert(QStringLiteral("colorTransfer"), s.value(QStringLiteral("color_transfer")).toString());
                m.insert(QStringLiteral("colorPrimaries"), s.value(QStringLiteral("color_primaries")).toString());
                m.insert(QStringLiteral("fieldOrder"), s.value(QStringLiteral("field_order")).toString());
            } else if (type == QLatin1String("audio") && !audio) {
                audio = true;
                m.insert(QStringLiteral("audioCodec"), s.value(QStringLiteral("codec_name")).toString());
                m.insert(QStringLiteral("channels"), s.value(QStringLiteral("channels")).toInt());
                m.insert(QStringLiteral("channelLayout"), s.value(QStringLiteral("channel_layout")).toString());
                m.insert(QStringLiteral("sampleRate"), s.value(QStringLiteral("sample_rate")).toString().toInt());
                m.insert(QStringLiteral("audioBitrate"), s.value(QStringLiteral("bit_rate")).toString().toDouble());
            }
        }
        m_probe = m;
        emit probeChanged();
        if (!video) {
            QSaveFile f(cacheDir() + QLatin1Char('/') + cacheKey(m_file) + QStringLiteral(".probe.json"));
            if (f.open(QIODevice::WriteOnly)) { f.write(QJsonDocument(QJsonObject::fromVariantMap(m_probe)).toJson()); f.commit(); }
            return;
        }
        // Variable frame rate check (phones, screen recorders): look at the gaps between the
        // first 20 s of video packet timestamps. Editors handle VFR badly, so flag it.
        QProcess *q = spawn(QStringLiteral("ffprobe"), { QStringLiteral("-v"), QStringLiteral("error"), QStringLiteral("-select_streams"), QStringLiteral("v:0"),
                                                        QStringLiteral("-read_intervals"), QStringLiteral("%+20"), QStringLiteral("-show_entries"),
                                                        QStringLiteral("packet=pts_time"), QStringLiteral("-of"), QStringLiteral("csv=p=0"), m_file });
        if (!q) return;
        connect(q, &QProcess::finished, this, [this, q, gen](int) {
            if (gen != m_generation) return;
            QVector<double> pts;
            for (const QByteArray &line : q->readAllStandardOutput().split('\n')) {
                bool ok = false;
                const double t = line.trimmed().replace(',', "").toDouble(&ok);
                if (ok) pts << t;
            }
            std::sort(pts.begin(), pts.end());
            QVector<double> d;
            for (int i = 1; i < pts.size(); ++i)
                if (pts[i] > pts[i - 1]) d << pts[i] - pts[i - 1];
            if (d.size() >= 20) {
                QVector<double> sorted = d;
                std::sort(sorted.begin(), sorted.end());
                const double median = sorted[sorted.size() / 2];
                int odd = 0;
                for (double x : d)
                    if (qAbs(x - median) > 0.2 * median) ++odd;
                const bool vfr = odd > d.size() / 50; // more than 2% of frames off the regular spacing
                m_probe.insert(QStringLiteral("vfr"), vfr);
                m_probe.insert(QStringLiteral("fpsMin"), 1.0 / sorted.last());
                m_probe.insert(QStringLiteral("fpsMax"), 1.0 / sorted.first());
            }
            QSaveFile f(cacheDir() + QLatin1Char('/') + cacheKey(m_file) + QStringLiteral(".probe.json"));
            if (f.open(QIODevice::WriteOnly)) { f.write(QJsonDocument(QJsonObject::fromVariantMap(m_probe)).toJson()); f.commit(); }
            emit probeChanged();
        });
        q->start();
    });
    p->start();
}

// ---- queue thumbnails and durations ------------------------------------------------
void Media::setQueue(const QStringList &files)
{
    if (files == m_queue) return;
    m_queue = files;
    m_queueTodo.clear();
    for (const QString &f : files) {
        const QString base = cacheDir() + QLatin1Char('/') + cacheKey(f);
        if (QFileInfo::exists(base + QStringLiteral(".thumb.jpg")))
            m_thumbs.insert(f, QUrl::fromLocalFile(base + QStringLiteral(".thumb.jpg")).toString());
        QFile d(base + QStringLiteral(".dur"));
        if (d.open(QIODevice::ReadOnly))
            m_durations.insert(f, d.readAll().toDouble());
        if (!m_durations.contains(f) || (!m_thumbs.contains(f) && !isAudioFile(f)))
            m_queueTodo << f;
    }
    ++m_queueRev;
    emit queueInfoChanged();
    if (!m_queueProc)
        pumpQueue();
}

void Media::pumpQueue()
{
    while (!m_queueTodo.isEmpty() && !QFileInfo(m_queueTodo.first()).isFile())
        m_queueTodo.removeFirst();
    if (m_queueTodo.isEmpty()) return;
    const QString f = m_queueTodo.first();
    const QString base = cacheDir() + QLatin1Char('/') + cacheKey(f);
    const QString probeExe = toolPath(QStringLiteral("ffprobe")), ffmpegExe = toolPath(QStringLiteral("ffmpeg"));
    if (probeExe.isEmpty() || ffmpegExe.isEmpty()) return;

    if (!m_durations.contains(f)) {
        auto *p = new QProcess(this);
        m_queueProc = p;
        connect(p, &QProcess::finished, this, [this, p, f, base](int) {
            p->deleteLater();
            bool ok = false;
            const double d = p->readAllStandardOutput().trimmed().toDouble(&ok);
            m_durations.insert(f, ok ? d : 0);
            QSaveFile out(base + QStringLiteral(".dur"));
            if (out.open(QIODevice::WriteOnly)) { out.write(QByteArray::number(ok ? d : 0)); out.commit(); }
            ++m_queueRev;
            emit queueInfoChanged();
            pumpQueue();
        });
        p->start(probeExe, { QStringLiteral("-v"), QStringLiteral("error"), QStringLiteral("-show_entries"), QStringLiteral("format=duration"),
                             QStringLiteral("-of"), QStringLiteral("csv=p=0"), f });
        return;
    }
    m_queueTodo.removeFirst();
    if (m_thumbs.contains(f) || isAudioFile(f)) {
        pumpQueue();
        return;
    }
    const double d = m_durations.value(f);
    const double at = d > 0 ? qMin(d * 0.1, 3.0) : 0;
    const QString out = base + QStringLiteral(".thumb.jpg");
    auto *p = new QProcess(this);
    m_queueProc = p;
    connect(p, &QProcess::finished, this, [this, p, f, out](int code) {
        p->deleteLater();
        if (code == 0 && QFileInfo(out).size() > 0) {
            m_thumbs.insert(f, QUrl::fromLocalFile(out).toString());
            ++m_queueRev;
            emit queueInfoChanged();
        }
        pumpQueue();
    });
    p->start(ffmpegExe, { QStringLiteral("-v"), QStringLiteral("error"), QStringLiteral("-nostdin"), QStringLiteral("-y"),
                          QStringLiteral("-ss"), QString::number(at, 'f', 2), QStringLiteral("-i"), f, QStringLiteral("-frames:v"), QStringLiteral("1"),
                          QStringLiteral("-vf"), QStringLiteral("scale=160:90:force_original_aspect_ratio=increase,crop=160:90"),
                          QStringLiteral("-q:v"), QStringLiteral("5"), out });
}

QString Media::thumbFor(const QString &file) const { return m_thumbs.value(file); }
double Media::durationFor(const QString &file) const { return m_durations.value(file, -1); }
