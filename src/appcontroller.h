#pragma once
#include "markermodel.h"
#include <QObject>
#include <QPointer>
#include <QProcess>
#include <QStringList>
#include <QUrl>
#include <QtQml/qqml.h>

class QQmlEngine;
class QJSEngine;

// Makes the core MarkerModel type known to QML (it lives in a library without QML).
struct MarkerModelForeign
{
    Q_GADGET
    QML_FOREIGN(MarkerModel)
    QML_NAMED_ELEMENT(MarkerModel)
    QML_UNCREATABLE("Provided by App.markers")
};

// App-level logic that is not playback: the folder queue, resume points,
// in/out points, markers and exports (clip, EDL, CSV, chapters, frame grab).
class AppController : public QObject
{
    Q_OBJECT
    QML_ANONYMOUS // exposed to QML as the "App" singleton instance in main.cpp
    Q_PROPERTY(MarkerModel *markers READ markers CONSTANT)
    Q_PROPERTY(QString currentFile READ currentFile NOTIFY currentFileChanged)
    Q_PROPERTY(QString currentName READ currentName NOTIFY currentFileChanged)
    Q_PROPERTY(QStringList queue READ queue NOTIFY queueChanged)
    Q_PROPERTY(int queueIndex READ queueIndex NOTIFY currentFileChanged)
    Q_PROPERTY(double inPoint READ inPoint WRITE setInPoint NOTIFY inOutChanged)
    Q_PROPERTY(double outPoint READ outPoint WRITE setOutPoint NOTIFY inOutChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(double busyProgress READ busyProgress NOTIFY busyChanged)
    Q_PROPERTY(bool ffmpegAvailable READ ffmpegAvailable CONSTANT)
    Q_PROPERTY(QStringList recentFiles READ recentFiles NOTIFY recentFilesChanged)

public:
    explicit AppController(QObject *parent = nullptr);
    // One shared instance for QML and C++.
    static AppController *instance();
    static AppController *create(QQmlEngine *, QJSEngine *);

    MarkerModel *markers() { return &m_markers; }
    QString currentFile() const { return m_current; }
    QString currentName() const;
    QStringList queue() const { return m_queue; }
    int queueIndex() const { return m_queue.indexOf(m_current); }
    double inPoint() const { return m_in; }
    double outPoint() const { return m_out; }
    void setInPoint(double t);
    void setOutPoint(double t);
    bool busy() const { return m_proc != nullptr; }
    double busyProgress() const { return m_progress; }
    bool ffmpegAvailable() const { return !ffmpegPath().isEmpty(); }
    QStringList recentFiles() const;

    // Returns the local path or URL to hand to mpv, and remembers it. Empty if not playable.
    Q_INVOKABLE QString prepareOpen(const QVariant &urlOrPath);
    Q_INVOKABLE QString nextInQueue(int direction) const;
    Q_INVOKABLE double resumePosition(const QString &file) const;
    Q_INVOKABLE void savePosition(double position, double duration);
    Q_INVOKABLE void clearInOut();

    Q_INVOKABLE void exportClip(bool lossless);
    Q_INVOKABLE void exportMarkersEdl(double fps);
    Q_INVOKABLE void exportMarkersCsv(double fps);
    Q_INVOKABLE void copyYouTubeChapters(double duration);
    Q_INVOKABLE QString frameGrabPath(qint64 frame) const;
    Q_INVOKABLE void revealInFolder(const QString &path) const;
    Q_INVOKABLE QString formatTimecode(double seconds, double fps) const;
    Q_INVOKABLE QString formatClock(double seconds) const;
    Q_INVOKABLE QString formatBytes(double bytes) const;
    Q_INVOKABLE void cancelJob();

    QString ffmpegPath() const;
    static QString uniquePath(const QString &wanted);

signals:
    void currentFileChanged();
    void queueChanged();
    void inOutChanged();
    void busyChanged();
    void recentFilesChanged();
    void message(const QString &text, const QString &revealPath);

private:
    void writeFile(const QString &path, const QString &content, const QString &what);
    QString baseOut() const;

    MarkerModel m_markers;
    QString m_current;
    QStringList m_queue;
    double m_in = -1, m_out = -1;
    QPointer<QProcess> m_proc;
    double m_progress = 0;
};
