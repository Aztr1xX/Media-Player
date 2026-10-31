#pragma once
#include <QObject>
#include <QPointer>
#include <QProcess>
#include <QVariantList>
#include <QtQml/qqml.h>

class QNetworkAccessManager;
class QNetworkReply;
class QFile;

// Offline speech-to-text with whisper.cpp (whisper-cli, run as a separate process).
// The model is downloaded once on first use; transcripts are cached per file.
class Transcript : public QObject
{
    Q_OBJECT
    QML_ANONYMOUS // exposed to QML as the "Transcript" singleton instance in main.cpp
    Q_PROPERTY(QString state READ state NOTIFY stateChanged)      // idle, downloading, preparing, transcribing, ready, error
    Q_PROPERTY(double progress READ progress NOTIFY stateChanged)
    Q_PROPERTY(QString error READ error NOTIFY stateChanged)
    Q_PROPERTY(QVariantList segments READ segments NOTIFY segmentsChanged)
    Q_PROPERTY(bool available READ available CONSTANT)
    Q_PROPERTY(bool modelReady READ modelReady NOTIFY stateChanged)
    Q_PROPERTY(QString model READ model WRITE setModel NOTIFY modelChanged)

public:
    static Transcript *instance();

    QString state() const { return m_state; }
    double progress() const { return m_progress; }
    QString error() const { return m_error; }
    QVariantList segments() const { return m_segments; }
    bool available() const;
    bool modelReady() const;
    QString model() const { return m_model; }
    void setModel(const QString &m);

    Q_INVOKABLE void load(const QString &file);  // show a cached transcript, if any
    Q_INVOKABLE void start(const QString &file); // download model if needed, then transcribe
    Q_INVOKABLE void cancel();
    Q_INVOKABLE int indexAt(double t) const;
    Q_INVOKABLE QString exportAs(const QString &format); // "srt" or "txt"; returns the written path
    Q_INVOKABLE static QString modelSizeLabel(const QString &model);

    QString modelPath() const;
    static QString parseWhisperJson(const QByteArray &json, QVariantList *out); // returns error text or empty
    static QString toSrt(const QVariantList &segments);

signals:
    void stateChanged();
    void segmentsChanged();
    void modelChanged();
    void finished(bool ok, const QString &message);

private:
    explicit Transcript(QObject *parent = nullptr);
    void setState(const QString &s, double progress = 0, const QString &err = QString());
    void download();
    void extractAudio();
    void runWhisper();
    QString cachePath(const QString &file) const;

    QString m_state = QStringLiteral("idle"), m_error, m_file, m_wav, m_model = QStringLiteral("base.en");
    double m_progress = 0;
    QVariantList m_segments;
    QNetworkAccessManager *m_net = nullptr;
    QPointer<QNetworkReply> m_reply;
    QFile *m_part = nullptr;
    QPointer<QProcess> m_proc;
};
