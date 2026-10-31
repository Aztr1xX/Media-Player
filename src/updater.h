#pragma once
#include <QObject>
#include <QNetworkAccessManager>
#include <QPointer>
#include <QQmlEngine>

class QNetworkReply;
class QFile;

// Checks the GitHub releases of the Slate repo for a newer build, downloads its installer
// and runs it silently. The installer closes Slate, updates it in place and reopens it.
class Updater : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString state READ state NOTIFY changed)          // idle, checking, current, available, downloading, ready, error
    Q_PROPERTY(QString latestVersion READ latestVersion NOTIFY changed)
    Q_PROPERTY(QString notes READ notes NOTIFY changed)
    Q_PROPERTY(double progress READ progress NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)
    Q_PROPERTY(bool supported READ supported CONSTANT)
public:
    explicit Updater(QObject *parent = nullptr);
    static Updater *instance();

    QString state() const { return m_state; }
    QString latestVersion() const { return m_latest; }
    QString notes() const { return m_notes; }
    double progress() const { return m_progress; }
    QString error() const { return m_error; }
    bool supported() const;

    Q_INVOKABLE void check(bool quiet = false);
    Q_INVOKABLE void download();
    Q_INVOKABLE void installAndRestart();

    // true when version a is newer than b ("1.1.12" > "1.1.9")
    static bool isNewer(const QString &a, const QString &b);

signals:
    void changed();

private:
    void set(const QString &state, const QString &err = {});
    QNetworkAccessManager m_net;
    QString m_state = QStringLiteral("idle");
    QString m_latest, m_notes, m_error, m_assetUrl, m_file;
    double m_progress = 0;
    bool m_quiet = false;
};
