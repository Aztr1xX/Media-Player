#include "mpvobject.h"
#include <QDir>
#include <QCoreApplication>
#include <QFileInfo>
#include <QStandardPaths>
#include <cstring>
#include "timecode.h"

#include <QMutex>
#include <QOpenGLContext>
#include <QOpenGLFunctions>
#include <QPointer>
#include <QOpenGLFramebufferObject>
#include <QQuickWindow>
#include <QDebug>
#include <clocale>
#include <cmath>
#include <memory>

// ---------------------------------------------------------------------------
// mpv_node <-> QVariant helpers
// ---------------------------------------------------------------------------
static QVariant nodeToVariant(const mpv_node *n)
{
    switch (n->format) {
    case MPV_FORMAT_STRING: return QString::fromUtf8(n->u.string);
    case MPV_FORMAT_FLAG: return bool(n->u.flag);
    case MPV_FORMAT_INT64: return qlonglong(n->u.int64);
    case MPV_FORMAT_DOUBLE: return n->u.double_;
    case MPV_FORMAT_NODE_ARRAY: {
        QVariantList l;
        for (int i = 0; i < n->u.list->num; ++i)
            l << nodeToVariant(&n->u.list->values[i]);
        return l;
    }
    case MPV_FORMAT_NODE_MAP: {
        QVariantMap m;
        for (int i = 0; i < n->u.list->num; ++i)
            m.insert(QString::fromUtf8(n->u.list->keys[i]), nodeToVariant(&n->u.list->values[i]));
        return m;
    }
    default: return {};
    }
}

// Owns a QVariant converted to an mpv_node (only flat values; enough for our use).
struct NodeBuilder {
    mpv_node node{};
    QByteArray str;
    explicit NodeBuilder(const QVariant &v)
    {
        switch (v.typeId()) {
        case QMetaType::Bool: node.format = MPV_FORMAT_FLAG; node.u.flag = v.toBool(); break;
        case QMetaType::Int: case QMetaType::LongLong: case QMetaType::UInt: case QMetaType::ULongLong:
            node.format = MPV_FORMAT_INT64; node.u.int64 = v.toLongLong(); break;
        case QMetaType::Double: case QMetaType::Float:
            node.format = MPV_FORMAT_DOUBLE; node.u.double_ = v.toDouble(); break;
        default:
            str = v.toString().toUtf8();
            node.format = MPV_FORMAT_STRING; node.u.string = str.data(); break;
        }
    }
};

// ---------------------------------------------------------------------------
// Shared mpv core: whichever of the item or renderer goes last tears mpv down,
// and the render context is always freed before the mpv handle.
// ---------------------------------------------------------------------------
struct MpvCore {
    mpv_handle *mpv = nullptr;
    mpv_render_context *gl = nullptr;
    // mpv calls back from its own threads; the item may already be gone.
    QMutex lock;
    QPointer<MpvObject> obj;
    ~MpvCore()
    {
        if (gl)
            mpv_render_context_free(gl);
        if (mpv)
            mpv_terminate_destroy(mpv);
    }
    void post(const char *slot)
    {
        QMutexLocker l(&lock);
        if (obj)
            QMetaObject::invokeMethod(obj.data(), slot, Qt::QueuedConnection);
    }
};
static QHash<const MpvObject *, std::shared_ptr<MpvCore>> &cores()
{
    static QHash<const MpvObject *, std::shared_ptr<MpvCore>> h;
    return h;
}

static void onWakeup(void *ctx) { static_cast<MpvCore *>(ctx)->post("onMpvEvents"); }
static void onRedraw(void *ctx) { static_cast<MpvCore *>(ctx)->post("doUpdate"); }
static void *getProcAddress(void *, const char *name)
{
    QOpenGLContext *glctx = QOpenGLContext::currentContext();
    return glctx ? reinterpret_cast<void *>(glctx->getProcAddress(QByteArray(name))) : nullptr;
}

// ---------------------------------------------------------------------------
// Renderer (runs on Qt's render thread)
// ---------------------------------------------------------------------------
class MpvRenderer : public QQuickFramebufferObject::Renderer
{
public:
    MpvRenderer(MpvObject *obj, std::shared_ptr<MpvCore> core) : m_obj(obj), m_core(std::move(core)) {}
    ~MpvRenderer() override
    {
        // Called with the GL context current: the right place to free the render context.
        if (m_core->gl) {
            mpv_render_context_free(m_core->gl);
            m_core->gl = nullptr;
        }
    }

    QOpenGLFramebufferObject *createFramebufferObject(const QSize &size) override
    {
        if (!m_core->gl && m_core->mpv) {
            // Software OpenGL (Mesa llvmpipe, Windows "GDI Generic") intermittently corrupts
            // mpv's 16-bit float intermediate buffers; 8-bit ones are reliable there.
            // Real GPUs keep mpv's higher-precision default.
            if (QOpenGLContext *c = QOpenGLContext::currentContext()) {
                const QByteArray r = reinterpret_cast<const char *>(c->functions()->glGetString(GL_RENDERER));
                for (const char *sw : { "llvmpipe", "softpipe", "SwiftShader", "GDI Generic", "Basic Render" })
                    if (r.contains(sw)) {
                        mpv_set_property_string(m_core->mpv, "fbo-format", "rgba8");
                        // and skip the multi-pass pipeline whose chroma planes go stale there
                        mpv_set_property_string(m_core->mpv, "gpu-dumb-mode", "yes");
                        qInfo("Slate: software OpenGL (%s); using 8-bit video buffers", r.constData());
                        break;
                    }
            }
            mpv_opengl_init_params glInit{ getProcAddress, nullptr };
            mpv_render_param params[] = {
                { MPV_RENDER_PARAM_API_TYPE, const_cast<char *>(MPV_RENDER_API_TYPE_OPENGL) },
                { MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, &glInit },
                { MPV_RENDER_PARAM_INVALID, nullptr },
            };
            mpv_render_context *ctx = nullptr;
            if (mpv_render_context_create(&ctx, m_core->mpv, params) < 0) {
                qWarning("Slate: failed to create mpv OpenGL render context");
            } else {
                m_core->gl = ctx;
                m_obj->setRenderContext(ctx);
                mpv_render_context_set_update_callback(ctx, onRedraw, m_core.get());
            }
        }
        QOpenGLFramebufferObjectFormat fmt;
        fmt.setAttachment(QOpenGLFramebufferObject::NoAttachment);
        return new QOpenGLFramebufferObject(size, fmt);
    }

    void render() override
    {
        if (!m_core->gl)
            return;
        QQuickWindow *win = m_obj->window();
        if (win)
            win->beginExternalCommands();
        QOpenGLFramebufferObject *fbo = framebufferObject();
        mpv_opengl_fbo mpfbo{ int(fbo->handle()), fbo->width(), fbo->height(), 0 };
        int flipY = 0;
        mpv_render_param params[] = {
            { MPV_RENDER_PARAM_OPENGL_FBO, &mpfbo },
            { MPV_RENDER_PARAM_FLIP_Y, &flipY },
            { MPV_RENDER_PARAM_INVALID, nullptr },
        };
        mpv_render_context_render(m_core->gl, params);
        if (win)
            win->endExternalCommands();
    }

private:
    MpvObject *m_obj;
    std::shared_ptr<MpvCore> m_core;
};

// ---------------------------------------------------------------------------
// MpvObject
// ---------------------------------------------------------------------------
MpvObject::MpvObject(QQuickItem *parent) : QQuickFramebufferObject(parent)
{
    std::setlocale(LC_NUMERIC, "C"); // mpv requires the C numeric locale

    auto core = std::make_shared<MpvCore>();
    core->mpv = mpv_create();
    m_mpv = core->mpv;
    if (!m_mpv) {
        qWarning("Slate: mpv_create failed");
        return;
    }
    core->obj = this;
    cores().insert(this, core);

    auto opt = [this](const char *k, const char *v) { mpv_set_option_string(m_mpv, k, v); };
    opt("vo", "libmpv");
    opt("hwdec", "auto-safe");        // hardware decoding where it is known to be reliable
    opt("keep-open", "yes");          // stay on the last frame at the end, so you can step back
    opt("idle", "yes");
    opt("hr-seek", "yes");            // exact seeks by default
    opt("hr-seek-framedrop", "no");
    opt("osc", "no");
    opt("input-default-bindings", "no");
    opt("input-vo-keyboard", "no");
    // SLATE_MPV_LOG=1 prints mpv's own log to the console for troubleshooting.
    const bool log = qEnvironmentVariableIsSet("SLATE_MPV_LOG");
    opt("terminal", log ? "yes" : "no");
    opt("audio-client-name", "Slate");
    opt("audio-fallback-to-null", "yes"); // keep playing (silently) if the audio device fails or is unplugged
    opt("screenshot-format", "png");
    opt("ytdl", "yes");               // plays URLs when yt-dlp is installed
    {
        // Prefer the yt-dlp that ships next to Slate.exe.
        const QString ytdlp = QDir(QCoreApplication::applicationDirPath()).filePath(QStringLiteral(
#ifdef Q_OS_WIN
            "yt-dlp.exe"
#else
            "yt-dlp"
#endif
            ));
        if (QFileInfo::exists(ytdlp))
            mpv_set_option_string(m_mpv, "script-opts", ("ytdl_hook-ytdl_path=" + QDir::toNativeSeparators(ytdlp)).toUtf8().constData());
    }
    opt("demuxer-max-back-bytes", "150MiB"); // cache behind playhead makes stepping backwards faster
    opt("msg-level", log ? "all=v" : "all=warn");
    opt("sub-auto", "fuzzy");         // pick up subtitles next to the file
    opt("audio-pitch-correction", "yes");
    // Power users can drop an mpv.conf, input-free scripts or shaders here; Slate's own
    // settings win where they overlap because they are applied after.
    const QByteArray cfg = configDir().toUtf8();
    if (!cfg.isEmpty()) {
        opt("config-dir", cfg.constData());
        opt("config", "yes");
        opt("load-scripts", "yes");
    }

    if (mpv_initialize(m_mpv) < 0) {
        qWarning("Slate: mpv_initialize failed");
        return;
    }

    mpv_observe_property(m_mpv, 0, "time-pos", MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, 0, "duration", MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, 0, "pause", MPV_FORMAT_FLAG);
    mpv_observe_property(m_mpv, 0, "speed", MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, 0, "volume", MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, 0, "mute", MPV_FORMAT_FLAG);
    mpv_observe_property(m_mpv, 0, "container-fps", MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, 0, "estimated-vf-fps", MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, 0, "media-title", MPV_FORMAT_STRING);
    mpv_observe_property(m_mpv, 0, "path", MPV_FORMAT_STRING);
    mpv_observe_property(m_mpv, 0, "eof-reached", MPV_FORMAT_FLAG);
    mpv_observe_property(m_mpv, 0, "video-format", MPV_FORMAT_STRING);
    mpv_observe_property(m_mpv, 0, "hwdec-current", MPV_FORMAT_STRING);
    mpv_observe_property(m_mpv, 0, "video-params/w", MPV_FORMAT_INT64);
    mpv_observe_property(m_mpv, 0, "track-list", MPV_FORMAT_NODE);
    mpv_observe_property(m_mpv, 0, "aid", MPV_FORMAT_STRING);
    mpv_observe_property(m_mpv, 0, "sid", MPV_FORMAT_STRING);

    mpv_set_wakeup_callback(m_mpv, onWakeup, core.get());
}

MpvObject::~MpvObject()
{
    // Stop mpv's callbacks reaching this object. The shared core (and mpv) lives on
    // until the renderer has freed the render context on the render thread.
    if (auto core = cores().value(this)) {
        QMutexLocker l(&core->lock);
        core->obj = nullptr;
    }
    if (m_mpv)
        command({ QStringLiteral("stop") });
    cores().remove(this);
}

QQuickFramebufferObject::Renderer *MpvObject::createRenderer() const
{
    window()->setPersistentGraphics(true);
    window()->setPersistentSceneGraph(true);
    return new MpvRenderer(const_cast<MpvObject *>(this), cores().value(this));
}

void MpvObject::doUpdate() { update(); }

qint64 MpvObject::frame() const
{
    // After an exact seek or frame step, time-pos is the frame's timestamp,
    // so this is exact for constant-frame-rate media.
    return Timecode::frameAt(m_position, m_fps);
}

void MpvObject::setPropertyAsync(const char *name, const QVariant &v)
{
    if (!m_mpv) return;
    NodeBuilder nb(v);
    mpv_set_property_async(m_mpv, 0, name, MPV_FORMAT_NODE, &nb.node);
}

void MpvObject::setPaused(bool p) { if (p != m_paused) setPropertyAsync("pause", p); }
void MpvObject::setSpeed(double s) { setPropertyAsync("speed", qBound(0.05, s, 16.0)); }
void MpvObject::setVolume(double v) { setPropertyAsync("volume", qBound(0.0, v, 130.0)); }
void MpvObject::setMuted(bool m) { setPropertyAsync("mute", m); }

void MpvObject::command(const QVariantList &args)
{
    if (!m_mpv || args.isEmpty()) return;
    QList<QByteArray> store;
    QVector<const char *> argv;
    for (const QVariant &a : args) {
        store << a.toString().toUtf8();
    }
    for (const QByteArray &b : store)
        argv << b.constData();
    argv << nullptr;
    mpv_command_async(m_mpv, 0, argv.data());
}

QVariant MpvObject::getProperty(const QString &name) const
{
    if (!m_mpv) return {};
    mpv_node node;
    if (mpv_get_property(m_mpv, name.toUtf8().constData(), MPV_FORMAT_NODE, &node) < 0)
        return {};
    QVariant v = nodeToVariant(&node);
    mpv_free_node_contents(&node);
    return v;
}

void MpvObject::setRenderContext(mpv_render_context *ctx)
{
    m_gl = ctx;
    m_glReady = true;
    // vo=libmpv fails ("Error opening ... video_out") if a file starts before the render
    // context exists, e.g. a file passed on the command line. Play any queued file now.
    QMetaObject::invokeMethod(this, [this] {
        if (!m_queuedFile.isEmpty()) {
            const QString f = m_queuedFile;
            m_queuedFile.clear();
            open(f, m_queuedStart);
        }
    }, Qt::QueuedConnection);
}

void MpvObject::open(const QString &fileOrUrl, double startAt)
{
    if (!m_mpv || fileOrUrl.isEmpty()) return;
    if (!m_glReady) {
        m_queuedFile = fileOrUrl;
        m_queuedStart = startAt;
        update(); // make sure the scene graph creates the renderer
        return;
    }
    m_pendingStart = startAt;
    // "start" is applied per file; set it before loading and clear it once loaded.
    mpv_set_property_string(m_mpv, "start", startAt > 0 ? QByteArray::number(startAt, 'f', 3).prepend('+').constData() : "none");
    m_loaded = false;
    emit loadedChanged();
    command({ QStringLiteral("loadfile"), fileOrUrl, QStringLiteral("replace") });
    setPaused(false);
}

void MpvObject::togglePause()
{
    if (m_atEnd && m_paused) { // replay from start when finished
        seekTo(0);
        setPaused(false);
        return;
    }
    setPaused(!m_paused);
}

void MpvObject::stepFrame(int direction)
{
    // frame-step / frame-back-step pause playback and move exactly one frame.
    command({ direction < 0 ? QStringLiteral("frame-back-step") : QStringLiteral("frame-step") });
}

void MpvObject::seekTo(double seconds, bool exact)
{
    if (m_duration > 0)
        seconds = qBound(0.0, seconds, m_duration);
    command({ QStringLiteral("seek"), QString::number(qMax(0.0, seconds), 'f', 6),
              exact ? QStringLiteral("absolute+exact") : QStringLiteral("absolute+keyframes") });
}

void MpvObject::seekBy(double seconds, bool exact)
{
    command({ QStringLiteral("seek"), QString::number(seconds, 'f', 6),
              exact ? QStringLiteral("relative+exact") : QStringLiteral("relative") });
}

void MpvObject::setLoop(double a, double b)
{
    if (a < 0 || b <= a) {
        mpv_set_property_string(m_mpv, "ab-loop-a", "no");
        mpv_set_property_string(m_mpv, "ab-loop-b", "no");
        m_loopA = m_loopB = -1;
    } else {
        double va = a, vb = b;
        mpv_set_property(m_mpv, "ab-loop-a", MPV_FORMAT_DOUBLE, &va);
        mpv_set_property(m_mpv, "ab-loop-b", MPV_FORMAT_DOUBLE, &vb);
        m_loopA = a; m_loopB = b;
        if (m_position < a || m_position > b)
            seekTo(a);
    }
    emit loopChanged();
}

bool MpvObject::screenshot(const QString &file)
{
    if (!m_mpv) return false;
    const QByteArray f = file.toUtf8();
    const char *args[] = { "screenshot-to-file", f.constData(), "video", nullptr };
    return mpv_command(m_mpv, args) >= 0;
}

void MpvObject::onMpvEvents()
{
    while (m_mpv) {
        mpv_event *ev = mpv_wait_event(m_mpv, 0);
        if (ev->event_id == MPV_EVENT_NONE)
            break;
        switch (ev->event_id) {
        case MPV_EVENT_PROPERTY_CHANGE:
            handleProperty(static_cast<mpv_event_property *>(ev->data));
            break;
        case MPV_EVENT_FILE_LOADED:
            mpv_set_property_string(m_mpv, "start", "none");
            m_loaded = true;
            m_atEnd = false;
            refreshInfo();
            emit loadedChanged();
            emit atEndChanged();
            emit fileLoaded();
            break;
        case MPV_EVENT_PLAYBACK_RESTART: // a seek or load finished: make sure the new frame is drawn
        case MPV_EVENT_VIDEO_RECONFIG:
            update();
            break;
        case MPV_EVENT_END_FILE: {
            auto *ef = static_cast<mpv_event_end_file *>(ev->data);
            if (ef->reason == MPV_END_FILE_REASON_ERROR) {
                m_loaded = false;
                emit loadedChanged();
            }
            if (ef->reason == MPV_END_FILE_REASON_ERROR)
                emit errorOccurred(QStringLiteral("Couldn't play this file: %1").arg(QString::fromUtf8(mpv_error_string(ef->error))));
            break;
        }
        default:
            break;
        }
    }
}

void MpvObject::handleProperty(mpv_event_property *p)
{
    const QByteArray name(p->name);
    const bool has = p->format != MPV_FORMAT_NONE && p->data;
    auto d = [&](double def = 0) { return (has && p->format == MPV_FORMAT_DOUBLE) ? *static_cast<double *>(p->data) : def; };
    auto b = [&]() { return has && p->format == MPV_FORMAT_FLAG && *static_cast<int *>(p->data); };
    auto s = [&]() { return (has && p->format == MPV_FORMAT_STRING) ? QString::fromUtf8(*static_cast<char **>(p->data)) : QString(); };

    if (name == "time-pos") { m_position = d(0); emit positionChanged(); }
    else if (name == "estimated-frame-number") { m_frameNumber = (has && p->format == MPV_FORMAT_INT64) ? *static_cast<int64_t *>(p->data) : -1; emit positionChanged(); }
    else if (name == "duration") { m_duration = d(0); emit durationChanged(); }
    else if (name == "pause") { m_paused = b(); emit pausedChanged(); }
    else if (name == "speed") { m_speed = d(1); emit speedChanged(); }
    else if (name == "volume") { m_volume = d(100); emit volumeChanged(); }
    else if (name == "mute") { m_muted = b(); emit mutedChanged(); }
    else if (name == "container-fps" || name == "estimated-vf-fps") {
        // Prefer the container's declared rate; fall back to the measured one.
        double c = 0, e = 0;
        mpv_get_property(m_mpv, "container-fps", MPV_FORMAT_DOUBLE, &c);
        mpv_get_property(m_mpv, "estimated-vf-fps", MPV_FORMAT_DOUBLE, &e);
        const double f = (c > 0 && std::isfinite(c)) ? c : ((e > 0 && std::isfinite(e)) ? e : 0);
        if (!qFuzzyCompare(f + 1, m_fps + 1)) { m_fps = f; emit fpsChanged(); }
    }
    else if (name == "media-title") { m_title = s(); emit mediaTitleChanged(); }
    else if (name == "path") { m_path = s(); emit pathChanged(); }
    else if (name == "eof-reached") {
        const bool e = b();
        if (e != m_atEnd) { m_atEnd = e; emit atEndChanged(); if (e) emit endOfFile(); }
    }
    else if (name == "track-list" && has && p->format == MPV_FORMAT_NODE) {
        const QVariantList all = nodeToVariant(static_cast<mpv_node *>(p->data)).toList();
        m_audioTracks.clear();
        m_subTracks.clear();
        for (const QVariant &v : all) {
            const QVariantMap t = v.toMap();
            QVariantMap e;
            e.insert(QStringLiteral("id"), t.value(QStringLiteral("id")).toInt());
            QStringList parts;
            if (!t.value(QStringLiteral("title")).toString().isEmpty()) parts << t.value(QStringLiteral("title")).toString();
            if (!t.value(QStringLiteral("lang")).toString().isEmpty()) parts << t.value(QStringLiteral("lang")).toString().toUpper();
            const QString codec = t.value(QStringLiteral("codec")).toString();
            if (!codec.isEmpty()) parts << codec;
            if (t.value(QStringLiteral("demux-channel-count")).toInt() > 0) parts << QStringLiteral("%1 ch").arg(t.value(QStringLiteral("demux-channel-count")).toInt());
            if (t.value(QStringLiteral("external")).toBool()) parts << QStringLiteral("external");
            e.insert(QStringLiteral("label"), parts.join(QStringLiteral(" · ")));
            const QString type = t.value(QStringLiteral("type")).toString();
            if (type == QLatin1String("audio")) m_audioTracks << e;
            else if (type == QLatin1String("sub")) m_subTracks << e;
        }
        emit tracksChanged();
    }
    else if (name == "aid" || name == "sid") {
        const QString v = s();
        const int id = (v == QLatin1String("no") || v.isEmpty()) ? 0 : v.toInt();
        if (name == "aid") m_aid = id; else m_sid = id;
        emit tracksChanged();
    }
    else if (name == "video-format" || name == "hwdec-current" || name == "video-params/w") {
        refreshInfo();
    }
}

void MpvObject::refreshInfo()
{
    QVariantMap m;
    auto put = [&](const char *key, const char *prop) {
        QVariant v = getProperty(QString::fromLatin1(prop));
        if (v.isValid() && !v.toString().isEmpty())
            m.insert(QString::fromLatin1(key), v);
    };
    put("width", "video-params/w");
    put("height", "video-params/h");
    put("videoCodec", "video-codec");
    put("pixelFormat", "video-params/pixelformat");
    put("primaries", "video-params/primaries");
    put("gamma", "video-params/gamma");
    put("hwdec", "hwdec-current");
    put("audioCodec", "audio-codec-name");
    put("sampleRate", "audio-params/samplerate");
    put("channels", "audio-params/channel-count");
    put("container", "file-format");
    put("fileSize", "file-size");
    put("containerFps", "container-fps");
    const bool video = !getProperty(QStringLiteral("video-format")).toString().isEmpty();
    const bool changed = (m != m_info) || (video != m_hasVideo);
    m_info = m;
    m_hasVideo = video;
    if (changed)
        emit videoInfoChanged();
}

void MpvObject::setMpvProperty(const QString &name, const QVariant &value)
{
    setPropertyAsync(name.toUtf8().constData(), value);
}

void MpvObject::setAudioTrack(int id)
{
    if (m_mpv) mpv_set_property_string(m_mpv, "aid", id > 0 ? QByteArray::number(id).constData() : "no");
}

void MpvObject::setSubtitleTrack(int id)
{
    if (m_mpv) mpv_set_property_string(m_mpv, "sid", id > 0 ? QByteArray::number(id).constData() : "no");
}

void MpvObject::addSubtitle(const QString &file)
{
    command({ QStringLiteral("sub-add"), file, QStringLiteral("select") });
}

QImage MpvObject::grabFrame(int maxWidth) const
{
    if (!m_mpv || !m_loaded || !m_hasVideo) return {};
    const char *args[] = { "screenshot-raw", "video", nullptr };
    mpv_node res;
    if (mpv_command_ret(m_mpv, args, &res) < 0) return {};
    QImage img;
    if (res.format == MPV_FORMAT_NODE_MAP) {
        int64_t w = 0, h = 0, stride = 0;
        QByteArray fmt;
        mpv_byte_array *data = nullptr;
        for (int i = 0; i < res.u.list->num; ++i) {
            const char *k = res.u.list->keys[i];
            const mpv_node &v = res.u.list->values[i];
            if (!strcmp(k, "w")) w = v.u.int64;
            else if (!strcmp(k, "h")) h = v.u.int64;
            else if (!strcmp(k, "stride")) stride = v.u.int64;
            else if (!strcmp(k, "format") && v.format == MPV_FORMAT_STRING) fmt = v.u.string;
            else if (!strcmp(k, "data") && v.format == MPV_FORMAT_BYTE_ARRAY) data = v.u.ba;
        }
        if (data && w > 0 && h > 0 && fmt == "bgr0") {
            // bgr0 in memory is 0xffRRGGBB-style RGB32 on little-endian machines.
            const QImage view(static_cast<const uchar *>(data->data), int(w), int(h), int(stride), QImage::Format_RGB32);
            img = w > maxWidth ? view.scaledToWidth(maxWidth, Qt::FastTransformation) : view.copy();
        }
    }
    mpv_free_node_contents(&res);
    return img;
}

QString MpvObject::configDir()
{
    QString d = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (d.isEmpty()) return {};
    d += QStringLiteral("/mpv");
    QDir().mkpath(d + QStringLiteral("/scripts"));
    return d;
}
