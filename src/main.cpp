#include "appcontroller.h"
#include "mpvobject.h"
#include "media.h"
#include "transcript.h"
#include "icons.h"
#include "visuals.h"
#include <QTest>

#include <QFont>
#include <QFontDatabase>
#include <QLocalServer>
#include <QLocalSocket>
#include <QSettings>

#include <QCommandLineParser>
#include <QDir>
#include <QFile>
#include <QElapsedTimer>
#include <QFileInfo>
#include <QGuiApplication>
#include <QIcon>
#include <QClipboard>
#include <QImage>
#include <QColor>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QSGRendererInterface>
#include <QTimer>
#include <clocale>
#include <cstdio>
#include <functional>

// ---------------------------------------------------------------------------
// --selftest: drives the real UI and engine through the main review workflow,
// prints PASS/FAIL for each check, saves a screenshot, and exits non-zero on failure.
// ---------------------------------------------------------------------------
class SelfTest : public QObject
{
public:
    SelfTest(QQuickWindow *w, MpvObject *mpv, AppController *app, QString file, QString shot)
        : m_win(w), m_mpv(mpv), m_app(app), m_file(std::move(file)), m_shot(std::move(shot)) {}

    void start()
    {
        if (!m_shot.isEmpty()) QFile::remove(m_shot + QStringLiteral(".log"));
        step("open file", [this] {
            QMetaObject::invokeMethod(m_win, "openMedia", Q_ARG(QVariant, QVariant(m_file)));
        }, [this] { return m_mpv->loaded() && m_mpv->duration() > 0 && m_mpv->fps() > 0; });
        step("pause", [this] { m_mpv->setPaused(true); }, [this] { return m_mpv->paused(); });
#ifdef Q_OS_WIN
        step("bundled tools present (ffmpeg, ffprobe)", [] {}, [] {
            std::printf("      whisper-cli bundled: %s\n", Transcript::instance()->available() ? "yes" : "no");
            return !Media::toolPath(QStringLiteral("ffmpeg")).isEmpty() && !Media::toolPath(QStringLiteral("ffprobe")).isEmpty();
        });
#endif
        step("audio waveform analysed", [] {}, [this] {
            return Media::instance()->waveformReady() && Media::instance()->peaks().size() > m_mpv->duration() * Media::kBinsPerSecond * 0.9;
        }, 30000);
        step("timeline thumbnails", [] {}, [] { return !Media::instance()->spriteUrl().isEmpty() && Media::instance()->spriteCount() > 0; }, 60000);
        step("stream facts and frame-rate check", [] {}, [] {
            const QVariantMap p = Media::instance()->probe();
            return p.value(QStringLiteral("width")).toInt() > 0 && p.contains(QStringLiteral("vfr")) && !p.value(QStringLiteral("vfr")).toBool();
        }, 20000);
        step("loudness measured", [] {}, [] { return Media::instance()->loudness().contains(QStringLiteral("integrated")); }, 60000);
        step("audio tracks listed", [] {}, [this] { return m_mpv->audioTracks().size() >= 1 && m_mpv->audioTrack() >= 1; });
        step("video scopes", [] {}, [this] {
            const QImage f = m_mpv->grabFrame(360);
            if (f.isNull()) return false;
            for (int mode = 0; mode < 4; ++mode)
                if (ScopeItem::render(f, mode, QSize(300, 200)).isNull()) return false;
            return true;
        });
        step("rate clip", [this] { m_app->setRating(m_file, 4); }, [this] { return m_app->rating(m_file) == 4; });
        step("window active for keyboard", [this] { m_win->raise(); m_win->requestActivate(); }, [this] { return QGuiApplication::focusWindow() == m_win; }, 3000);
        step("keyboard: M adds a marker", [this] { m_app->markers()->clear(); QTest::keyClick(m_win, Qt::Key_M); },
             [this] { return m_app->markers()->count() == 1; });
        step("keyboard: remapped shortcut", [this] {
            m_app->setSetting(QStringLiteral("keys/marker"), QStringLiteral("Shift+B"));
            m_win->setProperty("keymapRevision", m_win->property("keymapRevision").toInt() + 1);
            QTimer::singleShot(100, this, [this] { QTest::keyClick(m_win, Qt::Key_B, Qt::ShiftModifier); });
        }, [this] { return m_app->markers()->count() == 2; });
        step("restore shortcut", [this] {
            m_app->setSetting(QStringLiteral("keys/marker"), QString());
            m_win->setProperty("keymapRevision", m_win->property("keymapRevision").toInt() + 1);
            m_app->markers()->clear();
        }, [this] { return m_app->markers()->count() == 0; });
        step("settings open and close", [this] { QMetaObject::invokeMethod(m_win, "openSettings", Q_ARG(QVariant, QVariant(4))); },
             [this] { return m_win->property("settingsOpen").toBool(); });
        step("settings closed", [this] { QMetaObject::invokeMethod(m_win, "closeSettings"); },
             [this] { return !m_win->property("settingsOpen").toBool(); });
        step("transcript parser", [] {}, [] {
            QVariantList segs;
            const QByteArray j = R"({"transcription":[{"timestamps":{"from":"00:00:00,000","to":"00:00:02,500"},"offsets":{"from":0,"to":2500},"text":" Hello there."},)"
                                 R"({"offsets":{"from":2500,"to":4000},"text":" [BLANK_AUDIO]"},{"offsets":{"from":4000,"to":6200},"text":" Second line"}]})";
            const QString err = Transcript::parseWhisperJson(j, &segs);
            return err.isEmpty() && segs.size() == 2 && segs[1].toMap().value(QStringLiteral("start")).toDouble() == 4.0
                && Transcript::toSrt(segs).startsWith(QStringLiteral("1\n00:00:00,000 --> 00:00:02,500\nHello there."));
        });
        step("exact seek to 2.0 s", [this] { m_mpv->seekTo(2.0); }, [this] { return qAbs(m_mpv->position() - 2.0) < 0.02; });
        step("frame step forward", [this] { m_f0 = m_mpv->frame(); m_mpv->stepFrame(1); }, [this] { return m_mpv->frame() == m_f0 + 1; });
        step("frame step back", [this] { m_mpv->stepFrame(-1); }, [this] { return m_mpv->frame() == m_f0; });
        step("set in point", [this] { m_app->setInPoint(m_mpv->position()); }, [this] { return m_app->inPoint() > 1.9; });
        step("seek to 4.0 s and set out", [this] { m_mpv->seekTo(4.0); }, [this] { return qAbs(m_mpv->position() - 4.0) < 0.02; });
        step("out point", [this] { m_app->setOutPoint(m_mpv->position()); }, [this] { return m_app->outPoint() > 3.9; });
        step("add markers", [this] {
            m_app->markers()->clear();
            m_app->markers()->add(1.0, 1, QStringLiteral("Good slate"));
            m_app->markers()->add(12.0, 0, QStringLiteral("B-roll here"));
            m_app->markers()->add(25.0, 2, QStringLiteral("Mistake"));
        }, [this] { return m_app->markers()->count() == 3; });
        step("export EDL + CSV", [this] {
            connect(m_app, &AppController::message, this, [this](const QString &t, const QString &p) { m_lastMsg = t; m_lastPath = p; });
            m_app->exportMarkersEdl(m_mpv->fps());
        }, [this] { return m_lastPath.endsWith(QLatin1String(".edl")) && QFileInfo::exists(m_lastPath); });
        step("export CSV", [this] { m_app->exportMarkersCsv(m_mpv->fps()); },
             [this] { return m_lastPath.endsWith(QLatin1String(".csv")) && QFileInfo::exists(m_lastPath); });
        step("lossless clip export", [this] { m_lastPath.clear(); m_app->exportClip(true); },
             [this] { return !m_app->busy() && !m_lastPath.isEmpty() && QFileInfo(m_lastPath).size() > 1000; }, 20000);
        step("frame-exact clip export", [this] { m_lastPath.clear(); m_app->exportClip(false); },
             [this] { return !m_app->busy() && m_lastPath.endsWith(QLatin1String(".mp4")) && QFileInfo(m_lastPath).size() > 1000; }, 60000);
        step("YouTube chapters to clipboard", [this] {
            QGuiApplication::clipboard()->clear();
            m_app->markers()->add(10.0, 0, QStringLiteral("Setup"));
            m_app->markers()->add(20.0, 0, QStringLiteral("Desk"));
            m_app->copyYouTubeChapters(m_mpv->duration());
        }, [this] { return QGuiApplication::clipboard()->text() == QStringLiteral("0:00 Intro\n0:10 Setup\n0:20 Desk"); });
        step("frame grab", [this] { m_grab = m_app->frameGrabPath(m_mpv->frame()); m_mpv->screenshot(m_grab); },
             [this] { return QFileInfo(m_grab).size() > 1000; });
        step("A-B loop", [this] { m_mpv->setLoop(2.0, 4.0); }, [this] { return m_mpv->loopA() == 2.0; });
        step("open command palette", [this] { QMetaObject::invokeMethod(m_win, "openPalette"); },
             [this] { return m_win->property("paletteOpen").toBool(); });
        step("close palette", [this] { QMetaObject::invokeMethod(m_win, "closePalette"); },
             [this] { return !m_win->property("paletteOpen").toBool(); });
        step("play", [this] { m_mpv->setLoop(-1, -1); m_mpv->setPaused(false); m_p0 = m_mpv->position(); },
             [this] { return !m_mpv->paused() && m_mpv->position() > m_p0 + 0.3; });
        step("next file in folder", [this] {
            m_next = m_app->nextInQueue(1);
            QMetaObject::invokeMethod(m_win, "openNext", Q_ARG(QVariant, QVariant(1)));
        }, [this] { return !m_next.isEmpty() && m_app->currentFile() == m_next && m_mpv->loaded(); });
        step("back to first file (as if double-clicked in Explorer)", [this] { m_app->handOver(m_file); },
             [this] { return m_app->currentFile() == m_file && m_mpv->loaded() && m_mpv->duration() > 0; });
        step("compare two clips", [this] { QMetaObject::invokeMethod(m_win, "startCompare", Q_ARG(QVariant, QVariant(m_next))); }, [this] {
            const auto all = m_win->findChildren<MpvObject *>();
            return all.size() == 2 && all[0]->loaded() && all[1]->loaded();
        }, 10000);
        step("end comparison", [this] { QMetaObject::invokeMethod(m_win, "stopCompare"); },
             [this] { return m_win->findChildren<MpvObject *>().size() == 1; });
        step("screenshot", [this] {
            m_mpv->setPaused(true);
            m_mpv->seekTo(5.0);
        }, [this] {
            if (qAbs(m_mpv->position() - 5.0) > 0.02) return false;
            if (!m_settle.isValid()) m_settle.start();
            if (m_settle.elapsed() < 800) return false; // let the new frame reach the screen
            QImage img = m_win->grabWindow();
            // The centre of the video area must not be black: proves frames are drawn.
            const QColor c = img.pixelColor(img.width() / 3, img.height() / 2);
            if (c.name() != m_lastPixel) say(QStringLiteral("      video pixel at centre: %1").arg(m_lastPixel = c.name()));
            if (c.lightness() < 8) { if (!m_shot.isEmpty()) { img.save(m_shot + QStringLiteral(".black.png")); m_mpv->screenshot(m_shot + QStringLiteral(".decoded.png")); } return false; }
            return !m_shot.isEmpty() ? img.save(m_shot) : !img.isNull();
        });
        next();
    }

private:
    // Prints, and also appends to <screenshot>.log because Windows GUI apps have no console.
    void say(const QString &line)
    {
        std::printf("%s\n", qPrintable(line));
        std::fflush(stdout);
        if (!m_shot.isEmpty()) {
            QFile f(m_shot + QStringLiteral(".log"));
            if (f.open(QIODevice::Append | QIODevice::Text))
                f.write(line.toUtf8() + '\n');
        }
    }
    struct Step { QString name; std::function<void()> act; std::function<bool()> check; int timeout; };
    void step(const QString &n, std::function<void()> a, std::function<bool()> c, int timeout = 6000)
    {
        m_steps.push_back({ n, std::move(a), std::move(c), timeout });
    }
    void next()
    {
        if (m_i >= m_steps.size()) {
            say(QStringLiteral("SELFTEST %1 (%2 failed)").arg(m_failed ? "FAILED" : "PASSED").arg(m_failed));
            QCoreApplication::exit(m_failed ? 1 : 0);
            return;
        }
        Step &s = m_steps[m_i];
        s.act();
        m_clock.start();
        poll();
    }
    void poll()
    {
        Step &s = m_steps[m_i];
        if (s.check()) {
            say(QStringLiteral("PASS  %1  (%2 ms)").arg(s.name).arg(m_clock.elapsed()));
        } else if (m_clock.elapsed() > s.timeout) {
            say(QStringLiteral("FAIL  %1  [pos=%2 frame=%3 fps=%4 msg=%5]").arg(s.name).arg(m_mpv->position(), 0, 'f', 3)
                    .arg(m_mpv->frame()).arg(m_mpv->fps(), 0, 'f', 3).arg(m_lastMsg));
            ++m_failed;
        } else {
            QTimer::singleShot(50, this, [this] { poll(); });
            return;
        }
        std::fflush(stdout);
        ++m_i;
        QTimer::singleShot(150, this, [this] { next(); });
    }

    QQuickWindow *m_win; MpvObject *m_mpv; AppController *m_app; QString m_file, m_shot;
    QVector<Step> m_steps; int m_i = 0, m_failed = 0; QElapsedTimer m_clock;
    qint64 m_f0 = 0; double m_p0 = 0; QString m_lastMsg, m_lastPath, m_grab, m_next, m_lastPixel; QElapsedTimer m_settle;
};


// ---------------------------------------------------------------------------
// --tour <dir>: opens a file, then saves a screenshot of each main screen, for design review.
// ---------------------------------------------------------------------------
class Tour : public QObject
{
public:
    Tour(QQuickWindow *w, QString file, QString dir) : m_win(w), m_file(std::move(file)), m_dir(std::move(dir)) {}
    void start()
    {
        QDir().mkpath(m_dir);
        if (!m_file.isEmpty())
            QMetaObject::invokeMethod(m_win, "openMedia", Q_ARG(QVariant, QVariant(m_file)));
        // name, action, delay before the shot
        m_shots = {
            { QStringLiteral("01-review"), [this] { call("showTab", 0); }, 6000 },
            { QStringLiteral("02-clips"), [this] { call("showTab", 1); }, 2500 },
            { QStringLiteral("03-info"), [this] { call("showTab", 2); }, 800 },
            { QStringLiteral("04-transcript"), [this] { call("showTab", 3); }, 800 },
            { QStringLiteral("05-scopes"), [this] { call("showTab", 4); }, 1500 },
            { QStringLiteral("06-palette"), [this] { QMetaObject::invokeMethod(m_win, "openPalette"); }, 800 },
            { QStringLiteral("07-settings"), [this] { QMetaObject::invokeMethod(m_win, "closePalette"); call("openSettings", 0); }, 800 },
            { QStringLiteral("08-shortcuts"), [this] { call("openSettings", 4); }, 800 },
            { QStringLiteral("09-windows"), [this] { call("openSettings", 5); }, 800 },
            { QStringLiteral("10-fullscreen"), [this] { QMetaObject::invokeMethod(m_win, "closeSettings"); QMetaObject::invokeMethod(m_win, "toggleFullscreen"); }, 1500 },
        };
        next();
    }
private:
    struct Shot { QString name; std::function<void()> act; int delay; };
    void call(const char *fn, int arg) { QMetaObject::invokeMethod(m_win, fn, Q_ARG(QVariant, QVariant(arg))); }
    void next()
    {
        if (m_i >= m_shots.size()) { QCoreApplication::exit(0); return; }
        Shot &s = m_shots[m_i];
        s.act();
        QTimer::singleShot(s.delay, this, [this] {
            const QString out = m_dir + QLatin1Char('/') + m_shots[m_i].name + QStringLiteral(".png");
            m_win->grabWindow().save(out);
            std::printf("tour: %s\n", qPrintable(out));
            ++m_i;
            next();
        });
    }
    QQuickWindow *m_win; QString m_file, m_dir; QVector<Shot> m_shots; int m_i = 0;
};

// Generated by qt_add_qml_module; registers the C++ types (MpvObject, App) under "Slate".
void qml_register_types_Slate();

int main(int argc, char *argv[])
{
    // libmpv's render API draws with OpenGL; Qt 6 defaults to Direct3D on Windows.
    QQuickWindow::setGraphicsApi(QSGRendererInterface::OpenGL);
    QQuickStyle::setStyle(QStringLiteral("Basic"));

    QGuiApplication app(argc, argv);
    QGuiApplication::setOrganizationName(QStringLiteral("Slate"));
    QGuiApplication::setApplicationName(QStringLiteral("Slate"));
    QGuiApplication::setApplicationVersion(QStringLiteral(PROJECT_VERSION_STRING));
    std::setlocale(LC_NUMERIC, "C");

    QCommandLineParser cli;
    cli.setApplicationDescription(QStringLiteral("Slate: a media player for reviewing clips"));
    cli.addHelpOption();
    cli.addVersionOption();
    cli.addPositionalArgument(QStringLiteral("file"), QStringLiteral("File, folder or URL to open"));
    QCommandLineOption selftest(QStringLiteral("selftest"), QStringLiteral("Run the built-in workflow test on <file>"));
    QCommandLineOption shot(QStringLiteral("screenshot"), QStringLiteral("Save a window screenshot (after the self-test, or 2.5 s after opening) and quit"), QStringLiteral("png"));
    cli.addOption(selftest);
    cli.addOption(shot);
    QCommandLineOption newWindow(QStringLiteral("new-window"), QStringLiteral("Open a separate window even if Slate is already running"));
    cli.addOption(newWindow);
    QCommandLineOption tourOpt(QStringLiteral("tour"), QStringLiteral("Save screenshots of each screen to <dir> and quit"), QStringLiteral("dir"));
    cli.addOption(tourOpt);
    cli.process(app);
    const QStringList files = cli.positionalArguments();

    // One window: a second launch (e.g. double-clicking another file in Explorer) hands
    // its file to the running Slate and exits.
    const QString serverName = QStringLiteral("slate-player-") + qEnvironmentVariable("USERNAME", qEnvironmentVariable("USER"));
    const bool single = !cli.isSet(selftest) && !cli.isSet(shot) && !cli.isSet(newWindow) && !cli.isSet(tourOpt)
        && QSettings().value(QStringLiteral("prefs/singleWindow"), true).toBool();
    if (single) {
        QLocalSocket probe;
        probe.connectToServer(serverName);
        if (probe.waitForConnected(300)) {
            const QString f = files.isEmpty() ? QString() : (QFileInfo::exists(files.first()) ? QFileInfo(files.first()).absoluteFilePath() : files.first());
            probe.write(f.toUtf8() + '\n');
            probe.flush();
            probe.waitForBytesWritten(1000);
            probe.disconnectFromServer();
            return 0;
        }
    }

    app.setWindowIcon(QIcon(QStringLiteral(":/Slate/assets/slate.png")));
#ifdef Q_OS_WIN
    QFont uiFont(QStringLiteral("Segoe UI Variable Text"));
    if (!QFontDatabase::families().contains(uiFont.family())) uiFont.setFamily(QStringLiteral("Segoe UI"));
#else
    QFont uiFont(QFontDatabase::families().contains(QStringLiteral("Inter")) ? QStringLiteral("Inter") : QGuiApplication::font().family());
#endif
    uiFont.setPixelSize(13);
    uiFont.setHintingPreference(QFont::PreferNoHinting);
    QGuiApplication::setFont(uiFont);

    qml_register_types_Slate();
    AppController &controller = *AppController::instance();
    qmlRegisterSingletonInstance("Slate", 1, 0, "App", &controller);
    qmlRegisterSingletonInstance("Slate", 1, 0, "Media", Media::instance());
    qmlRegisterSingletonInstance("Slate", 1, 0, "Transcript", Transcript::instance());

    QLocalServer server;
    if (single) {
        QLocalServer::removeServer(serverName); // clear a stale socket left by a crash
        server.listen(serverName);
        QObject::connect(&server, &QLocalServer::newConnection, &server, [&server, &controller] {
            while (QLocalSocket *s = server.nextPendingConnection()) {
                QObject::connect(s, &QLocalSocket::readyRead, s, [s, &controller] {
                    if (!s->canReadLine()) return;
                    const QString f = QString::fromUtf8(s->readLine()).trimmed();
                    controller.handOver(f);
                    s->disconnectFromServer();
                });
                QObject::connect(s, &QLocalSocket::disconnected, s, &QObject::deleteLater);
            }
        });
    }

    QQmlApplicationEngine engine;
    engine.addImageProvider(QStringLiteral("icon"), new IconProvider);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app, [] { QCoreApplication::exit(2); }, Qt::QueuedConnection);
    engine.load(QUrl(QStringLiteral("qrc:/Slate/Main.qml")));
    if (engine.rootObjects().isEmpty())
        return 2;

    auto *win = qobject_cast<QQuickWindow *>(engine.rootObjects().first());

    if (cli.isSet(tourOpt)) {
        auto *t = new Tour(win, files.isEmpty() ? QString() : QFileInfo(files.first()).absoluteFilePath(), cli.value(tourOpt));
        QTimer::singleShot(300, t, [t] { t->start(); });
    } else if (cli.isSet(selftest)) {
        if (files.isEmpty()) {
            std::fprintf(stderr, "--selftest needs a media file\n");
            return 3;
        }
        auto *mpv = win->findChild<MpvObject *>();
        auto *t = new SelfTest(win, mpv, &controller, QFileInfo(files.first()).absoluteFilePath(), cli.value(shot));
        QTimer::singleShot(300, t, [t] { t->start(); });
    } else {
        if (!files.isEmpty()) {
            const QString f = QFileInfo::exists(files.first()) ? QFileInfo(files.first()).absoluteFilePath() : files.first();
            QTimer::singleShot(0, win, [win, f] { QMetaObject::invokeMethod(win, "openMedia", Q_ARG(QVariant, QVariant(f))); });
        }
        if (cli.isSet(shot)) { // smoke test: open, wait, save a screenshot, quit
            const QString out = cli.value(shot);
            QTimer::singleShot(2500, win, [win, out] {
                const bool ok = win->grabWindow().save(out);
                std::printf("screenshot %s: %s\n", ok ? "saved" : "FAILED", qPrintable(out));
                QCoreApplication::exit(ok ? 0 : 1);
            });
        }
    }
    return app.exec();
}
