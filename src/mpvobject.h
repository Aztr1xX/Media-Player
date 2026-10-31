#pragma once
#include <atomic>
#include <QImage>
#include <QQuickFramebufferObject>
#include <QVariant>
#include <QtQml/qqml.h>
#include <mpv/client.h>
#include <mpv/render_gl.h>

class MpvRenderer;

// A QML item that shows libmpv video through mpv's OpenGL render API and
// exposes playback state as properties. All mpv access goes through here.
class MpvObject : public QQuickFramebufferObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString path READ path NOTIFY pathChanged)
    Q_PROPERTY(QString mediaTitle READ mediaTitle NOTIFY mediaTitleChanged)
    Q_PROPERTY(double position READ position NOTIFY positionChanged)
    Q_PROPERTY(double duration READ duration NOTIFY durationChanged)
    Q_PROPERTY(bool paused READ paused WRITE setPaused NOTIFY pausedChanged)
    Q_PROPERTY(double speed READ speed WRITE setSpeed NOTIFY speedChanged)
    Q_PROPERTY(double volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(bool muted READ muted WRITE setMuted NOTIFY mutedChanged)
    Q_PROPERTY(double fps READ fps NOTIFY fpsChanged)
    Q_PROPERTY(qint64 frame READ frame NOTIFY positionChanged)
    Q_PROPERTY(bool hasVideo READ hasVideo NOTIFY videoInfoChanged)
    Q_PROPERTY(bool loaded READ loaded NOTIFY loadedChanged)
    Q_PROPERTY(bool atEnd READ atEnd NOTIFY atEndChanged)
    Q_PROPERTY(QVariantMap info READ info NOTIFY videoInfoChanged)
    Q_PROPERTY(double loopA READ loopA NOTIFY loopChanged)
    Q_PROPERTY(double loopB READ loopB NOTIFY loopChanged)
    Q_PROPERTY(QVariantList audioTracks READ audioTracks NOTIFY tracksChanged)
    Q_PROPERTY(QVariantList subtitleTracks READ subtitleTracks NOTIFY tracksChanged)
    Q_PROPERTY(int audioTrack READ audioTrack NOTIFY tracksChanged)      // 0 = off
    Q_PROPERTY(int subtitleTrack READ subtitleTrack NOTIFY tracksChanged) // 0 = off

public:
    explicit MpvObject(QQuickItem *parent = nullptr);
    ~MpvObject() override;
    Renderer *createRenderer() const override;

    QString path() const { return m_path; }
    QString mediaTitle() const { return m_title; }
    double position() const { return m_position; }
    double duration() const { return m_duration; }
    bool paused() const { return m_paused; }
    double speed() const { return m_speed; }
    double volume() const { return m_volume; }
    bool muted() const { return m_muted; }
    double fps() const { return m_fps; }
    qint64 frame() const;
    bool hasVideo() const { return m_hasVideo; }
    bool loaded() const { return m_loaded; }
    bool atEnd() const { return m_atEnd; }
    QVariantMap info() const { return m_info; }
    double loopA() const { return m_loopA; }
    double loopB() const { return m_loopB; }
    QVariantList audioTracks() const { return m_audioTracks; }
    QVariantList subtitleTracks() const { return m_subTracks; }
    int audioTrack() const { return m_aid; }
    int subtitleTrack() const { return m_sid; }

    void setPaused(bool p);
    void setSpeed(double s);
    void setVolume(double v);
    void setMuted(bool m);

    Q_INVOKABLE void open(const QString &fileOrUrl, double startAt = 0);
    Q_INVOKABLE void togglePause();
    Q_INVOKABLE void stepFrame(int direction);           // +1 next frame, -1 previous frame
    Q_INVOKABLE void seekTo(double seconds, bool exact = true);
    Q_INVOKABLE void seekBy(double seconds, bool exact = false);
    Q_INVOKABLE void setLoop(double a, double b);        // a<0 clears
    Q_INVOKABLE bool screenshot(const QString &file);    // full-resolution frame grab
    Q_INVOKABLE void command(const QVariantList &args);
    Q_INVOKABLE QVariant getProperty(const QString &name) const;
    Q_INVOKABLE void setMpvProperty(const QString &name, const QVariant &value);
    Q_INVOKABLE void setAudioTrack(int id);
    Q_INVOKABLE void setSubtitleTrack(int id);
    Q_INVOKABLE void addSubtitle(const QString &file);
    // Copy of the current video frame, scaled to at most maxWidth (for scopes).
    QImage grabFrame(int maxWidth) const;
    static QString configDir(); // mpv.conf and scripts/ for power users

    // Used by the renderer.
    mpv_handle *handle() const { return m_mpv; }
    mpv_render_context *renderContext() const { return m_gl; }
    void setRenderContext(mpv_render_context *ctx); // render thread; flushes a queued open()

signals:
    void pathChanged();
    void mediaTitleChanged();
    void positionChanged();
    void durationChanged();
    void pausedChanged();
    void speedChanged();
    void volumeChanged();
    void mutedChanged();
    void fpsChanged();
    void videoInfoChanged();
    void loadedChanged();
    void atEndChanged();
    void loopChanged();
    void tracksChanged();
    void fileLoaded();
    void endOfFile();
    void errorOccurred(const QString &message);
    void requestUpdate();

private slots:
    void onMpvEvents();
    void doUpdate();

private:
    void handleProperty(mpv_event_property *p);
    void refreshInfo();
    void setPropertyAsync(const char *name, const QVariant &v);

    mpv_handle *m_mpv = nullptr;
    mpv_render_context *m_gl = nullptr;

    QString m_path, m_title;
    double m_position = 0, m_duration = 0, m_speed = 1, m_volume = 100, m_fps = 0;
    double m_loopA = -1, m_loopB = -1;
    bool m_paused = true, m_muted = false, m_hasVideo = false, m_loaded = false, m_atEnd = false;
    double m_pendingStart = 0;
    QString m_queuedFile;          // open() before the video surface exists
    double m_queuedStart = 0;
    std::atomic<bool> m_glReady{false};
    qint64 m_frameNumber = -1;
    QVariantMap m_info;
    QVariantList m_audioTracks, m_subTracks;
    int m_aid = 0, m_sid = 0;
};
