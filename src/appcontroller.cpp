#include "appcontroller.h"
#include "folderqueue.h"
#include "timecode.h"

#include <QClipboard>
#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QJSEngine>
#include <QSettings>
#include <QStandardPaths>
#include <QTextStream>
#include <QProcess>
#include <QKeySequence>
#include <cmath>

static QString settingsKey(const QString &file)
{
    return QString::fromLatin1(QCryptographicHash::hash(QFileInfo(file).absoluteFilePath().toUtf8(), QCryptographicHash::Sha1).toHex().left(20));
}

AppController::AppController(QObject *parent) : QObject(parent) {}

AppController *AppController::instance()
{
    static AppController *s = new AppController();
    return s;
}

AppController *AppController::create(QQmlEngine *, QJSEngine *)
{
    AppController *a = instance();
    QJSEngine::setObjectOwnership(a, QJSEngine::CppOwnership);
    return a;
}

QString AppController::currentName() const
{
    if (m_current.isEmpty())
        return {};
    const QUrl u(m_current);
    if (!u.scheme().isEmpty() && u.scheme().size() > 1 && !QFileInfo::exists(m_current))
        return m_current; // a URL
    return QFileInfo(m_current).fileName();
}

void AppController::setInPoint(double t)
{
    m_in = qMax(0.0, t);
    if (m_out >= 0 && m_out <= m_in)
        m_out = -1;
    emit inOutChanged();
}

void AppController::setOutPoint(double t)
{
    m_out = qMax(0.0, t);
    if (m_in >= 0 && m_in >= m_out)
        m_in = -1;
    emit inOutChanged();
}

void AppController::clearInOut()
{
    m_in = m_out = -1;
    emit inOutChanged();
}

QString AppController::prepareOpen(const QVariant &urlOrPath)
{
    QString target;
    if (urlOrPath.canConvert<QUrl>() && urlOrPath.toUrl().isValid() && !urlOrPath.toUrl().scheme().isEmpty()) {
        const QUrl u = urlOrPath.toUrl();
        target = u.isLocalFile() ? u.toLocalFile() : u.toString();
    } else {
        target = urlOrPath.toString().trimmed();
        if (target.startsWith(QLatin1String("file:")))
            target = QUrl(target).toLocalFile();
    }
    if (target.isEmpty())
        return {};

    const QFileInfo fi(target);
    const bool local = fi.exists();
    if (local && fi.isDir()) {
        // Opening a folder plays its first media file.
        const QStringList files = FolderQueue::mediaFilesIn(fi.absoluteFilePath());
        if (files.isEmpty()) {
            emit message(QStringLiteral("No media files in that folder"), QString());
            return {};
        }
        target = files.first();
    } else if (local) {
        target = fi.absoluteFilePath();
    }

    m_current = target;
    if (QFileInfo::exists(target)) {
        const QStringList q = FolderQueue::mediaFilesIn(QFileInfo(target).absolutePath());
        m_queue = q.contains(target) ? q : QStringList{ target };
    } else {
        m_queue = { target };
    }
    m_markers.loadFor(target);
    clearInOut();

    QSettings s;
    QStringList recent = s.value(QStringLiteral("recent")).toStringList();
    recent.removeAll(target);
    recent.prepend(target);
    while (recent.size() > 12)
        recent.removeLast();
    s.setValue(QStringLiteral("recent"), recent);

    emit queueChanged();
    emit currentFileChanged();
    emit recentFilesChanged();
    return target;
}

QStringList AppController::recentFiles() const
{
    return QSettings().value(QStringLiteral("recent")).toStringList();
}

QString AppController::nextInQueue(int direction) const
{
    const int i = m_queue.indexOf(m_current);
    const int j = i + (direction < 0 ? -1 : 1);
    return (i >= 0 && j >= 0 && j < m_queue.size()) ? m_queue.at(j) : QString();
}

double AppController::resumePosition(const QString &file) const
{
    return QSettings().value(QStringLiteral("resume/") + settingsKey(file), 0.0).toDouble();
}

void AppController::savePosition(double position, double duration)
{
    if (m_current.isEmpty() || !QFileInfo::exists(m_current))
        return;
    QSettings s;
    const QString key = QStringLiteral("resume/") + settingsKey(m_current);
    // Only remember a spot worth returning to: not the first or last 15 seconds.
    if (duration > 60 && position > 15 && position < duration - 15)
        s.setValue(key, position);
    else
        s.remove(key);
}

QString AppController::baseOut() const
{
    const QFileInfo fi(m_current);
    const QString custom = setting(QStringLiteral("exportFolder")).toString();
    // Default: a "Slate exports" folder beside the clip, so exports don't join the clip list.
    QString dir = (!custom.isEmpty() && QFileInfo(custom).isDir()) ? custom : fi.absolutePath() + QStringLiteral("/Slate exports");
    QDir().mkpath(dir);
    return dir + QLatin1Char('/') + fi.completeBaseName();
}

QString AppController::uniquePath(const QString &wanted)
{
    if (!QFileInfo::exists(wanted))
        return wanted;
    const QFileInfo fi(wanted);
    for (int i = 2; i < 1000; ++i) {
        const QString p = fi.absolutePath() + QLatin1Char('/') + fi.completeBaseName() + QStringLiteral(" (%1).").arg(i) + fi.suffix();
        if (!QFileInfo::exists(p))
            return p;
    }
    return wanted;
}

QString AppController::ffmpegPath() const
{
    // Bundled next to slate.exe first, then PATH.
    const QString local = QStandardPaths::findExecutable(QStringLiteral("ffmpeg"), { QCoreApplication::applicationDirPath() });
    return local.isEmpty() ? QStandardPaths::findExecutable(QStringLiteral("ffmpeg")) : local;
}

void AppController::exportClip(bool lossless)
{
    if (m_proc) {
        emit message(QStringLiteral("An export is already running"), QString());
        return;
    }
    if (!QFileInfo::exists(m_current)) {
        emit message(QStringLiteral("Open a local file first"), QString());
        return;
    }
    if (m_in < 0 || m_out <= m_in) {
        emit message(QStringLiteral("Set an In point (I) and an Out point (O) first"), QString());
        return;
    }
    const QString ff = ffmpegPath();
    if (ff.isEmpty()) {
        emit message(QStringLiteral("FFmpeg not found. Put ffmpeg.exe next to Slate or on PATH"), QString());
        return;
    }
    const QString suffix = lossless ? QFileInfo(m_current).suffix() : QStringLiteral("mp4");
    // File-name friendly times, e.g. 01m05s or 1h02m05s.
    const auto stamp = [](double t) {
        const qint64 s = qint64(std::floor(t)), h = s / 3600, m = (s / 60) % 60, sec = s % 60;
        const QString ms = QStringLiteral("%1m%2s").arg(m, 2, 10, QLatin1Char('0')).arg(sec, 2, 10, QLatin1Char('0'));
        return h > 0 ? QString::number(h) + QLatin1Char('h') + ms : ms;
    };
    const QString out = uniquePath(baseOut() + QStringLiteral("_%1-%2.").arg(stamp(m_in), stamp(m_out)) + suffix);
    const double dur = m_out - m_in;

    QStringList args{ QStringLiteral("-hide_banner"), QStringLiteral("-nostdin"), QStringLiteral("-y"),
                      QStringLiteral("-progress"), QStringLiteral("pipe:1"), QStringLiteral("-nostats"),
                      QStringLiteral("-ss"), QString::number(m_in, 'f', 3),
                      QStringLiteral("-i"), m_current,
                      QStringLiteral("-t"), QString::number(dur, 'f', 3),
                      QStringLiteral("-map"), QStringLiteral("0:v?"), QStringLiteral("-map"), QStringLiteral("0:a?") };
    if (lossless) {
        // Stream copy: instant and untouched, but the start snaps to the keyframe before In.
        args << QStringLiteral("-c") << QStringLiteral("copy") << QStringLiteral("-avoid_negative_ts") << QStringLiteral("make_zero");
    } else {
        // Frame-exact: re-encode at high quality.
        args << QStringLiteral("-c:v") << QStringLiteral("libx264") << QStringLiteral("-crf") << QStringLiteral("16")
             << QStringLiteral("-preset") << QStringLiteral("medium") << QStringLiteral("-pix_fmt") << QStringLiteral("yuv420p")
             << QStringLiteral("-c:a") << QStringLiteral("aac") << QStringLiteral("-b:a") << QStringLiteral("320k")
             << QStringLiteral("-movflags") << QStringLiteral("+faststart");
    }
    args << out;

    auto *p = new QProcess(this);
    m_proc = p;
    m_progress = 0;
    emit busyChanged();
    connect(p, &QProcess::readyReadStandardOutput, this, [this, p, dur]() {
        while (p->canReadLine()) {
            const QByteArray line = p->readLine().trimmed();
            if (line.startsWith("out_time_us=") || line.startsWith("out_time_ms=")) {
                const double us = line.mid(line.indexOf('=') + 1).toDouble();
                m_progress = qBound(0.0, us / 1e6 / qMax(0.001, dur), 1.0);
                emit busyChanged();
            }
        }
    });
    connect(p, &QProcess::finished, this, [this, p, out](int code, QProcess::ExitStatus st) {
        const bool ok = st == QProcess::NormalExit && code == 0 && QFileInfo(out).size() > 0;
        if (ok)
            emit message(QStringLiteral("Saved %1").arg(QFileInfo(out).fileName()), out);
        else {
            const QString err = QString::fromUtf8(p->readAllStandardError()).trimmed().section(QLatin1Char('\n'), -1);
            QFile::remove(out);
            emit message(QStringLiteral("Export failed: %1").arg(err.isEmpty() ? QStringLiteral("cancelled") : err), QString());
        }
        p->deleteLater();
        m_proc = nullptr;
        emit busyChanged();
    });
    p->start(ff, args);
    if (!p->waitForStarted(5000)) {
        emit message(QStringLiteral("Couldn't start FFmpeg"), QString());
        p->deleteLater();
        m_proc = nullptr;
        emit busyChanged();
    }
}

void AppController::cancelJob()
{
    if (m_proc)
        m_proc->kill();
}

void AppController::writeFile(const QString &path, const QString &content, const QString &what)
{
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        emit message(QStringLiteral("Couldn't save %1: %2").arg(what, f.errorString()), QString());
        return;
    }
    QTextStream ts(&f);
    ts << content;
    emit message(QStringLiteral("Saved %1").arg(QFileInfo(path).fileName()), path);
}

void AppController::exportMarkersEdl(double fps)
{
    if (m_markers.count() == 0) {
        emit message(QStringLiteral("No markers to export. Press M to add one"), QString());
        return;
    }
    // Resolve timelines start at 01:00:00:00 by default.
    const qint64 offset = qint64(3600) * Timecode::nominalFps(fps);
    const QString edl = MarkerModel::toEdl(m_markers.items(), fps, currentName(), offset);
    writeFile(uniquePath(baseOut() + QStringLiteral("_markers.edl")), edl, QStringLiteral("EDL"));
}

void AppController::exportMarkersCsv(double fps)
{
    if (m_markers.count() == 0) {
        emit message(QStringLiteral("No markers to export. Press M to add one"), QString());
        return;
    }
    writeFile(uniquePath(baseOut() + QStringLiteral("_markers.csv")), MarkerModel::toCsv(m_markers.items(), fps), QStringLiteral("CSV"));
}

void AppController::copyYouTubeChapters(double duration)
{
    const auto c = MarkerModel::toYouTubeChapters(m_markers.items(), duration);
    if (!c.error.isEmpty()) {
        emit message(c.error, QString());
        return;
    }
    QGuiApplication::clipboard()->setText(c.text);
    emit message(c.skipped ? QStringLiteral("Copied %1 chapters (%2 markers too close together were skipped)").arg(c.count).arg(c.skipped)
                           : QStringLiteral("Copied %1 chapters to the clipboard").arg(c.count),
                 QString());
}

QString AppController::frameGrabPath(qint64 frame) const
{
    if (!QFileInfo::exists(m_current)) {
        const QString pics = QStandardPaths::writableLocation(QStandardPaths::PicturesLocation);
        return uniquePath(pics + QStringLiteral("/Slate frame %1.png").arg(frame));
    }
    return uniquePath(baseOut() + QStringLiteral("_frame%1.png").arg(frame));
}

void AppController::revealInFolder(const QString &path) const
{
#ifdef Q_OS_WIN
    // Opens Explorer with the file selected.
    QProcess::startDetached(QStringLiteral("explorer.exe"), { QStringLiteral("/select,"), QDir::toNativeSeparators(path) });
#else
    QDesktopServices::openUrl(QUrl::fromLocalFile(QFileInfo(path).absolutePath()));
#endif
}

QString AppController::version() const { return QCoreApplication::applicationVersion(); }

bool AppController::isWindows() const
{
#ifdef Q_OS_WIN
    return true;
#else
    return false;
#endif
}

QVariant AppController::setting(const QString &key, const QVariant &fallback) const
{
    QVariant v = QSettings().value(QStringLiteral("prefs/") + key, fallback);
    // INI-backed settings come back as strings; hand QML the type it asked for.
    if (fallback.isValid() && v.metaType() != fallback.metaType()) {
        QVariant c = v;
        if (c.convert(fallback.metaType())) return c;
        return fallback;
    }
    return v;
}

QString AppController::keyText(int key, int modifiers) const
{
    if (key == Qt::Key_Control || key == Qt::Key_Shift || key == Qt::Key_Alt || key == Qt::Key_Meta || key == 0 || key == Qt::Key_unknown)
        return {};
    return QKeySequence(QKeyCombination(Qt::KeyboardModifiers(modifiers & (Qt::ControlModifier | Qt::ShiftModifier | Qt::AltModifier | Qt::MetaModifier)),
                                        Qt::Key(key))).toString(QKeySequence::PortableText);
}

void AppController::setSetting(const QString &key, const QVariant &value)
{
    QSettings().setValue(QStringLiteral("prefs/") + key, value);
}

int AppController::rating(const QString &file) const
{
    return QSettings().value(QStringLiteral("rating/") + settingsKey(file), 0).toInt();
}

void AppController::setRating(const QString &file, int stars)
{
    if (file.isEmpty()) return;
    QSettings s;
    const QString key = QStringLiteral("rating/") + settingsKey(file);
    if (stars <= 0) s.remove(key); else s.setValue(key, qBound(1, stars, 5));
    ++m_ratingsRev;
    emit ratingsChanged();
}

void AppController::removeRecent(const QString &file)
{
    QSettings s;
    QStringList r = s.value(QStringLiteral("recent")).toStringList();
    r.removeAll(file);
    s.setValue(QStringLiteral("recent"), r);
    emit recentFilesChanged();
}

void AppController::clearRecent()
{
    QSettings().remove(QStringLiteral("recent"));
    emit recentFilesChanged();
}

QString AppController::localPath(const QVariant &v) const
{
    if (v.canConvert<QUrl>() && v.toUrl().isLocalFile()) return v.toUrl().toLocalFile();
    const QString s = v.toString();
    return s.startsWith(QLatin1String("file:")) ? QUrl(s).toLocalFile() : s;
}

bool AppController::isSubtitleFile(const QVariant &v) const
{
    static const QStringList ext = { QStringLiteral("srt"), QStringLiteral("ass"), QStringLiteral("ssa"), QStringLiteral("vtt"), QStringLiteral("sub") };
    return ext.contains(QFileInfo(localPath(v)).suffix().toLower());
}

void AppController::openDefaultAppsSettings() const
{
#ifdef Q_OS_WIN
    // Jump straight to Slate's page in Settings > Apps > Default apps.
    const bool machine = QSettings(QStringLiteral("HKEY_LOCAL_MACHINE\\Software\\RegisteredApplications"), QSettings::NativeFormat).contains(QStringLiteral("Slate"));
    QDesktopServices::openUrl(QUrl(machine ? QStringLiteral("ms-settings:defaultapps?registeredAppMachine=Slate")
                                           : QStringLiteral("ms-settings:defaultapps?registeredAppUser=Slate")));
#endif
}

void AppController::openFolder(const QString &path) const
{
    QDir().mkpath(path);
    QDesktopServices::openUrl(QUrl::fromLocalFile(path));
}

QString AppController::mpvConfigDir() const
{
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + QStringLiteral("/mpv");
}

QString AppController::exportFolderLabel() const
{
    const QString custom = setting(QStringLiteral("exportFolder")).toString();
    return custom.isEmpty() ? QStringLiteral("A \"Slate exports\" folder next to the clip") : QDir::toNativeSeparators(custom);
}

QString AppController::formatTimecode(double seconds, double fps) const
{
    return Timecode::fromSeconds(seconds, fps);
}

QString AppController::formatClock(double seconds) const
{
    return Timecode::clock(seconds);
}

QString AppController::formatBytes(double bytes) const
{
    if (bytes <= 0) return QStringLiteral("unknown");
    const char *u[] = { "B", "KB", "MB", "GB", "TB" };
    int i = 0;
    while (bytes >= 1024 && i < 4) { bytes /= 1024; ++i; }
    return QString::number(bytes, 'f', i == 0 ? 0 : 1) + QLatin1Char(' ') + QLatin1String(u[i]);
}
