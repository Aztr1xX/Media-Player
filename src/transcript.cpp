#include "transcript.h"
#include "media.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QRegularExpression>
#include <QSaveFile>
#include <QStandardPaths>
#include <QThread>
#include <cmath>

Transcript::Transcript(QObject *parent) : QObject(parent) {}

Transcript *Transcript::instance()
{
    static Transcript *t = new Transcript();
    return t;
}

bool Transcript::available() const { return !Media::toolPath(QStringLiteral("whisper-cli")).isEmpty(); }

QString Transcript::modelPath() const
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + QStringLiteral("/models");
    QDir().mkpath(dir);
    return dir + QStringLiteral("/ggml-%1.bin").arg(m_model);
}

bool Transcript::modelReady() const { return QFileInfo(modelPath()).size() > 50 * 1024 * 1024; }

void Transcript::setModel(const QString &m)
{
    static const QStringList ok = { QStringLiteral("base.en"), QStringLiteral("base"), QStringLiteral("small.en"), QStringLiteral("small") };
    if (!ok.contains(m) || m == m_model) return;
    m_model = m;
    emit modelChanged();
    emit stateChanged();
}

QString Transcript::modelSizeLabel(const QString &model)
{
    return model.startsWith(QLatin1String("small")) ? QStringLiteral("466 MB") : QStringLiteral("142 MB");
}

QString Transcript::cachePath(const QString &file) const
{
    return Media::cacheDir() + QLatin1Char('/') + Media::cacheKey(file) + QStringLiteral(".transcript.json");
}

void Transcript::setState(const QString &s, double progress, const QString &err)
{
    m_state = s;
    m_progress = progress;
    m_error = err;
    emit stateChanged();
}

void Transcript::load(const QString &file)
{
    if (m_proc || m_reply) {
        if (file == m_file) return;
        cancel();
    }
    m_file = file;
    m_segments.clear();
    QFile f(cachePath(file));
    if (QFileInfo(file).isFile() && f.open(QIODevice::ReadOnly)) {
        m_segments = QJsonDocument::fromJson(f.readAll()).array().toVariantList();
        setState(QStringLiteral("ready"), 1);
    } else {
        setState(QStringLiteral("idle"));
    }
    emit segmentsChanged();
}

void Transcript::start(const QString &file)
{
    cancel();
    m_file = file;
    if (!available()) {
        setState(QStringLiteral("error"), 0, QStringLiteral("whisper-cli wasn't found next to Slate"));
        return;
    }
    if (!QFileInfo(file).isFile()) {
        setState(QStringLiteral("error"), 0, QStringLiteral("Transcripts work on local files only"));
        return;
    }
    if (!modelReady()) download();
    else extractAudio();
}

void Transcript::cancel()
{
    if (m_reply) { m_reply->disconnect(this); m_reply->abort(); m_reply->deleteLater(); }
    if (m_part) { m_part->close(); m_part->remove(); delete m_part; m_part = nullptr; }
    if (m_proc) { m_proc->disconnect(this); m_proc->kill(); m_proc->deleteLater(); }
    if (!m_wav.isEmpty()) { QFile::remove(m_wav); m_wav.clear(); }
    if (m_state != QLatin1String("ready") && m_state != QLatin1String("idle"))
        setState(m_segments.isEmpty() ? QStringLiteral("idle") : QStringLiteral("ready"), m_segments.isEmpty() ? 0 : 1);
}

void Transcript::download()
{
    if (!m_net) m_net = new QNetworkAccessManager(this);
    const QUrl url(QStringLiteral("https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-%1.bin").arg(m_model));
    m_part = new QFile(modelPath() + QStringLiteral(".part"));
    if (!m_part->open(QIODevice::WriteOnly)) {
        delete m_part; m_part = nullptr;
        setState(QStringLiteral("error"), 0, QStringLiteral("Couldn't save the speech model"));
        return;
    }
    QNetworkRequest req(url);
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    m_reply = m_net->get(req);
    setState(QStringLiteral("downloading"), 0);
    connect(m_reply, &QNetworkReply::readyRead, this, [this] { if (m_part && m_reply) m_part->write(m_reply->readAll()); });
    connect(m_reply, &QNetworkReply::downloadProgress, this, [this](qint64 got, qint64 total) {
        if (total > 0) { m_progress = double(got) / total; emit stateChanged(); }
    });
    connect(m_reply, &QNetworkReply::finished, this, [this] {
        QNetworkReply *r = m_reply;
        m_reply = nullptr;
        r->deleteLater();
        if (!m_part) return;
        m_part->write(r->readAll());
        m_part->close();
        const bool ok = r->error() == QNetworkReply::NoError && m_part->size() > 50 * 1024 * 1024;
        if (!ok) {
            m_part->remove();
            delete m_part; m_part = nullptr;
            setState(QStringLiteral("error"), 0, QStringLiteral("Couldn't download the speech model (%1)").arg(r->errorString()));
            emit finished(false, m_error);
            return;
        }
        QFile::remove(modelPath());
        m_part->rename(modelPath());
        delete m_part; m_part = nullptr;
        extractAudio();
    });
}

void Transcript::extractAudio()
{
    // whisper wants 16 kHz mono 16-bit WAV.
    m_wav = QDir::tempPath() + QStringLiteral("/slate-%1.wav").arg(Media::cacheKey(m_file));
    auto *p = new QProcess(this);
    m_proc = p;
    setState(QStringLiteral("preparing"), 0);
    connect(p, &QProcess::finished, this, [this, p](int code) {
        p->deleteLater();
        if (code != 0 || QFileInfo(m_wav).size() < 1000) {
            setState(QStringLiteral("error"), 0, QStringLiteral("This file has no audio to transcribe"));
            emit finished(false, m_error);
            return;
        }
        runWhisper();
    });
    p->start(Media::toolPath(QStringLiteral("ffmpeg")), { QStringLiteral("-v"), QStringLiteral("error"), QStringLiteral("-nostdin"), QStringLiteral("-y"),
                                                         QStringLiteral("-i"), m_file, QStringLiteral("-map"), QStringLiteral("0:a:0"), QStringLiteral("-ac"), QStringLiteral("1"),
                                                         QStringLiteral("-ar"), QStringLiteral("16000"), QStringLiteral("-c:a"), QStringLiteral("pcm_s16le"), m_wav });
}

void Transcript::runWhisper()
{
    const QString outBase = m_wav.left(m_wav.size() - 4);
    auto *p = new QProcess(this);
    m_proc = p;
    setState(QStringLiteral("transcribing"), 0);
    connect(p, &QProcess::readyReadStandardError, this, [this, p] {
        static const QRegularExpression re(QStringLiteral("progress\\s*=\\s*(\\d+)%"));
        auto it = re.globalMatch(QString::fromUtf8(p->readAllStandardError()));
        while (it.hasNext()) m_progress = it.next().captured(1).toDouble() / 100.0;
        emit stateChanged();
    });
    connect(p, &QProcess::finished, this, [this, p, outBase](int code) {
        p->deleteLater();
        QFile::remove(m_wav);
        m_wav.clear();
        QFile json(outBase + QStringLiteral(".json"));
        QVariantList segs;
        QString err = code == 0 && json.open(QIODevice::ReadOnly) ? parseWhisperJson(json.readAll(), &segs) : QStringLiteral("Transcription failed");
        json.close();
        json.remove();
        if (!err.isEmpty()) {
            setState(QStringLiteral("error"), 0, err);
            emit finished(false, err);
            return;
        }
        m_segments = segs;
        QSaveFile f(cachePath(m_file));
        if (f.open(QIODevice::WriteOnly)) {
            f.write(QJsonDocument(QJsonArray::fromVariantList(segs)).toJson(QJsonDocument::Compact));
            f.commit();
        }
        emit segmentsChanged();
        setState(QStringLiteral("ready"), 1);
        emit finished(true, QStringLiteral("Transcript ready: %1 lines").arg(segs.size()));
    });
    const int threads = qBound(1, QThread::idealThreadCount() - 1, 8);
    p->start(Media::toolPath(QStringLiteral("whisper-cli")),
             { QStringLiteral("-m"), modelPath(), QStringLiteral("-f"), m_wav, QStringLiteral("-oj"), QStringLiteral("-of"), outBase,
               QStringLiteral("-t"), QString::number(threads), QStringLiteral("-pp"), QStringLiteral("-np"),
               QStringLiteral("-l"), m_model.endsWith(QLatin1String(".en")) ? QStringLiteral("en") : QStringLiteral("auto") });
}

QString Transcript::parseWhisperJson(const QByteArray &json, QVariantList *out)
{
    QJsonParseError pe;
    const QJsonDocument doc = QJsonDocument::fromJson(json, &pe);
    if (pe.error != QJsonParseError::NoError)
        return QStringLiteral("Couldn't read the transcript");
    out->clear();
    for (const QJsonValue &v : doc.object().value(QStringLiteral("transcription")).toArray()) {
        const QJsonObject o = v.toObject();
        const QJsonObject off = o.value(QStringLiteral("offsets")).toObject();
        const QString text = o.value(QStringLiteral("text")).toString().trimmed();
        if (text.isEmpty() || text == QLatin1String("[BLANK_AUDIO]")) continue;
        QVariantMap seg;
        seg.insert(QStringLiteral("start"), off.value(QStringLiteral("from")).toDouble() / 1000.0);
        seg.insert(QStringLiteral("end"), off.value(QStringLiteral("to")).toDouble() / 1000.0);
        seg.insert(QStringLiteral("text"), text);
        out->append(seg);
    }
    return {};
}

int Transcript::indexAt(double t) const
{
    int lo = 0, hi = int(m_segments.size()) - 1, found = -1;
    while (lo <= hi) {
        const int mid = (lo + hi) / 2;
        if (m_segments[mid].toMap().value(QStringLiteral("start")).toDouble() <= t) { found = mid; lo = mid + 1; }
        else hi = mid - 1;
    }
    return found;
}

QString Transcript::toSrt(const QVariantList &segments)
{
    auto ts = [](double s) {
        const qint64 ms = qint64(std::llround(s * 1000));
        return QStringLiteral("%1:%2:%3,%4").arg(ms / 3600000, 2, 10, QLatin1Char('0')).arg(ms / 60000 % 60, 2, 10, QLatin1Char('0'))
            .arg(ms / 1000 % 60, 2, 10, QLatin1Char('0')).arg(ms % 1000, 3, 10, QLatin1Char('0'));
    };
    QString out;
    int n = 1;
    for (const QVariant &v : segments) {
        const QVariantMap m = v.toMap();
        out += QStringLiteral("%1\n%2 --> %3\n%4\n\n").arg(n++).arg(ts(m.value(QStringLiteral("start")).toDouble()),
                                                           ts(m.value(QStringLiteral("end")).toDouble()), m.value(QStringLiteral("text")).toString());
    }
    return out;
}

QString Transcript::exportAs(const QString &format)
{
    if (m_segments.isEmpty() || m_file.isEmpty()) return {};
    const QFileInfo fi(m_file);
    QString path = fi.absolutePath() + QLatin1Char('/') + fi.completeBaseName() + (format == QLatin1String("srt") ? QStringLiteral(".srt") : QStringLiteral(".txt"));
    QString text;
    if (format == QLatin1String("srt")) text = toSrt(m_segments);
    else for (const QVariant &v : m_segments) text += v.toMap().value(QStringLiteral("text")).toString() + QLatin1Char('\n');
    QSaveFile f(path);
    if (!f.open(QIODevice::WriteOnly)) return {};
    f.write(text.toUtf8());
    return f.commit() ? path : QString();
}
