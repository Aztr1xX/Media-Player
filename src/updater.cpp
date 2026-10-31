#include "updater.h"
#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QProcess>
#include <QStandardPaths>
#include <QTimer>
#include <QVersionNumber>

static const char *kLatest = "https://api.github.com/repos/Aztr1xX/Media-Player/releases/latest";

Updater::Updater(QObject *parent) : QObject(parent) {}

Updater *Updater::instance()
{
    static Updater *u = new Updater(QCoreApplication::instance());
    QQmlEngine::setObjectOwnership(u, QQmlEngine::CppOwnership);
    return u;
}

bool Updater::supported() const
{
#ifdef Q_OS_WIN
    return true;
#else
    return qEnvironmentVariableIsSet("SLATE_FAKE_UPDATE");
#endif
}

bool Updater::isNewer(const QString &a, const QString &b)
{
    auto clean = [](QString s) { if (s.startsWith(QLatin1Char('v'))) s.remove(0, 1); return QVersionNumber::fromString(s); };
    return QVersionNumber::compare(clean(a), clean(b)) > 0;
}

void Updater::set(const QString &state, const QString &err)
{
    m_state = state;
    m_error = err;
    emit changed();
}

void Updater::check(bool quiet)
{
    if (m_state == QLatin1String("checking") || m_state == QLatin1String("downloading")) return;
    m_quiet = quiet;
    if (qEnvironmentVariableIsSet("SLATE_FAKE_UPDATE")) {   // for screenshots and testing the update UI
        m_latest = qEnvironmentVariable("SLATE_FAKE_UPDATE");
        m_assetUrl = QStringLiteral("about:blank");
        set(QStringLiteral("available"));
        return;
    }
    set(QStringLiteral("checking"));
    QNetworkRequest req{QUrl(QString::fromLatin1(kLatest))};
    req.setRawHeader("Accept", "application/vnd.github+json");
    req.setRawHeader("User-Agent", "Slate-updater");
    req.setTransferTimeout(15000);
    QNetworkReply *r = m_net.get(req);
    connect(r, &QNetworkReply::finished, this, [this, r] {
        r->deleteLater();
        if (r->error() != QNetworkReply::NoError) {
            set(m_quiet ? QStringLiteral("idle") : QStringLiteral("error"), QStringLiteral("Couldn't reach GitHub. Check your connection and try again."));
            return;
        }
        const QJsonObject o = QJsonDocument::fromJson(r->readAll()).object();
        m_latest = o.value(QStringLiteral("tag_name")).toString();
        if (m_latest.startsWith(QLatin1Char('v'))) m_latest.remove(0, 1);
        m_notes = o.value(QStringLiteral("body")).toString();
        m_assetUrl.clear();
        for (const QJsonValue &a : o.value(QStringLiteral("assets")).toArray()) {
            const QString name = a.toObject().value(QStringLiteral("name")).toString();
            if (name.startsWith(QLatin1String("Slate-Setup")) && name.endsWith(QLatin1String(".exe")))
                m_assetUrl = a.toObject().value(QStringLiteral("browser_download_url")).toString();
        }
        const bool newer = !m_latest.isEmpty() && !m_assetUrl.isEmpty() && isNewer(m_latest, QCoreApplication::applicationVersion());
        set(newer ? QStringLiteral("available") : QStringLiteral("current"));
    });
}

void Updater::download()
{
    if (m_assetUrl.isEmpty() || m_state == QLatin1String("downloading")) return;
    if (qEnvironmentVariableIsSet("SLATE_FAKE_UPDATE")) { m_progress = 1; set(QStringLiteral("ready")); return; }
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::TempLocation);
    m_file = QDir(dir).filePath(QStringLiteral("Slate-Setup-%1.exe").arg(m_latest));
    auto *out = new QFile(m_file, this);
    if (!out->open(QIODevice::WriteOnly)) { delete out; set(QStringLiteral("error"), QStringLiteral("Couldn't save the update to the temp folder.")); return; }
    m_progress = 0;
    set(QStringLiteral("downloading"));
    QNetworkRequest req{QUrl(m_assetUrl)};
    req.setRawHeader("User-Agent", "Slate-updater");
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    QNetworkReply *r = m_net.get(req);
    connect(r, &QNetworkReply::readyRead, this, [r, out] { out->write(r->readAll()); });
    connect(r, &QNetworkReply::downloadProgress, this, [this](qint64 got, qint64 total) {
        if (total > 0) { m_progress = double(got) / double(total); emit changed(); }
    });
    connect(r, &QNetworkReply::finished, this, [this, r, out] {
        r->deleteLater();
        out->write(r->readAll());
        out->close();
        out->deleteLater();
        if (r->error() != QNetworkReply::NoError || out->size() < 1024 * 1024) {
            QFile::remove(m_file);
            set(QStringLiteral("error"), QStringLiteral("The download didn't finish. Try again."));
            return;
        }
        m_progress = 1;
        set(QStringLiteral("ready"));
    });
}

void Updater::installAndRestart()
{
    if (m_state != QLatin1String("ready")) return;
    // /VERYSILENT: no wizard. The installer reopens Slate when it's done (see slate.iss).
    const bool ok = QProcess::startDetached(m_file, { QStringLiteral("/VERYSILENT"), QStringLiteral("/SUPPRESSMSGBOXES"),
                                                      QStringLiteral("/NORESTART"), QStringLiteral("/CLOSEAPPLICATIONS"),
                                                      QStringLiteral("/RELAUNCH") });
    if (!ok) { set(QStringLiteral("error"), QStringLiteral("Couldn't start the installer.")); return; }
    QTimer::singleShot(200, qApp, &QCoreApplication::quit);
}
