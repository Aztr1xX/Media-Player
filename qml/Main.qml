import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Slate

ApplicationWindow {
    id: win
    width: 1440
    height: 880
    minimumWidth: 960
    minimumHeight: 600
    visible: true
    color: Theme.bg
    title: App.currentName ? App.currentName + " – Slate" : "Slate"

    property bool panelsVisible: App.setting("panelsVisible", true)
    property int sideTab: App.setting("sideTab", 0)
    onSideTabChanged: App.setSetting("sideTab", sideTab)
    property bool paletteOpen: palette.opened
    readonly property bool isFull: visibility === Window.FullScreen
    property bool mouseRecently: true
    readonly property bool chromeVisible: !isFull || mouseRecently || !mpv.loaded || mpv.paused
    property int rewindRate: 0          // J held: 1, 2, 4, 8
    property bool skipSilence: false
    property double silenceSaved: 0
    property string compareFile: ""
    property double compareOffset: 0
    property int keymapRevision: 0
    property bool wasMaximized: false
    readonly property var speeds: [0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.5, 3, 4]

    // ----- actions --------------------------------------------------------------
    function toast(msg, path) { toastItem.show(msg, path) }
    function fmt(t) { return mpv.hasVideo && mpv.fps > 0 ? App.formatTimecode(t, mpv.fps) : App.formatClock(t) }

    function openMedia(target) {
        if (App.isSubtitleFile(target)) {
            if (mpv.loaded) { mpv.addSubtitle(App.localPath(target)); toast("Subtitles loaded") }
            return
        }
        if (mpv.loaded) App.savePosition(mpv.position, mpv.duration)
        const f = App.prepareOpen(target)
        if (!f) return
        stopCompare()
        const resume = App.setting("resume", true) ? App.resumePosition(f) : 0
        mpv.open(f, resume)
        if (resume > 0) toast("Resumed at " + App.formatClock(resume) + ". Press Home to start over")
        Transcript.load(f)
        Media.setQueue(App.queue)
    }
    function openNext(dir) {
        const f = App.nextInQueue(dir)
        if (f) openMedia(f); else toast(dir > 0 ? "That's the last clip in this folder" : "That's the first clip in this folder")
    }
    function openFileDialog() { fileDialog.open() }
    function openFolderDialog() { folderDialog.open() }
    function openSubtitleDialog() { subDialog.open() }
    function addMarker() {
        if (!mpv.loaded) return
        App.markers.add(mpv.position, 0, "")
        toast(panelsVisible && sideTab === 0 ? "Marker added. Double-click it to write a note" : "Marker added at " + fmt(mpv.position))
    }
    function setIn() { if (mpv.loaded) { App.inPoint = mpv.position; syncLoop() } }
    function setOut() { if (mpv.loaded) { App.outPoint = mpv.position; syncLoop() } }
    function clearInOut() { App.clearInOut(); mpv.setLoop(-1, -1); toast("In and Out cleared") }
    function syncLoop() { if (mpv.loopA >= 0) { if (App.inPoint >= 0 && App.outPoint > App.inPoint) mpv.setLoop(App.inPoint, App.outPoint); else mpv.setLoop(-1, -1) } }
    function toggleLoop() {
        if (mpv.loopA >= 0) { mpv.setLoop(-1, -1); toast("Loop off"); return }
        if (App.inPoint >= 0 && App.outPoint > App.inPoint) { mpv.setLoop(App.inPoint, App.outPoint); toast("Looping In to Out") }
        else toast("Set In (I) and Out (O) first")
    }
    function cycleSpeed(dir) {
        let i = speeds.findIndex(s => Math.abs(s - mpv.speed) < 0.001)
        if (i < 0) i = speeds.indexOf(1)
        i = Math.max(0, Math.min(speeds.length - 1, i + dir))
        mpv.speed = speeds[i]
        toast("Speed " + speeds[i] + "×")
    }
    function resetSpeed() { mpv.speed = 1; toast("Speed 1×") }
    function shuttle(key) {
        // J / K / L like editing apps. Repeated L plays faster; J rewinds in steps.
        if (key === "k") { rewindRate = 0; mpv.paused = true; mpv.speed = 1; return }
        if (key === "l") {
            rewindRate = 0
            if (mpv.paused) { mpv.speed = 1; mpv.paused = false }
            else mpv.speed = Math.min(8, mpv.speed >= 1 ? mpv.speed * 2 : 1)
            if (mpv.speed !== 1) toast("Playing " + mpv.speed + "×")
            return
        }
        mpv.paused = true
        rewindRate = rewindRate === 0 ? 1 : Math.min(8, rewindRate * 2)
        toast("Rewinding " + rewindRate + "×. K stops")
    }
    function grabFrame() {
        if (!mpv.loaded || !mpv.hasVideo) { toast("No video frame to save"); return }
        const p = App.frameGrabPath(mpv.frame)
        if (mpv.screenshot(p)) toast("Saved frame " + mpv.frame, p); else toast("Couldn't save the frame")
    }
    function toggleFullscreen() {
        if (isFull) visibility = wasMaximized ? Window.Maximized : Window.Windowed
        else { wasMaximized = visibility === Window.Maximized; visibility = Window.FullScreen }
    }
    function togglePanels() { panelsVisible = !panelsVisible; App.setSetting("panelsVisible", panelsVisible) }
    function showTab(i) { sideTab = i; if (!panelsVisible) togglePanels() }
    function jumpMarker(dir) {
        const t = dir > 0 ? App.markers.nextAfter(mpv.position + 0.001) : App.markers.prevBefore(mpv.position - 0.001)
        if (t >= 0) { mpv.paused = true; mpv.seekTo(t, true) } else toast(dir > 0 ? "No more markers after this" : "No markers before this")
    }
    function rate(n) {
        if (!App.currentFile) return
        App.setRating(App.currentFile, n)
        toast(n > 0 ? "Rated " + "★".repeat(n) : "Rating cleared")
    }
    function toggleSkipSilence() {
        skipSilence = !skipSilence
        silenceSaved = 0
        toast(skipSilence ? (Media.waveformReady ? "Skipping silences" : "Skipping silences once the audio has been read") : "Playing silences again")
    }
    function startCompare(f) {
        if (!mpv.loaded || !f) return
        compareFile = f
        compareOffset = 0
        toast("Comparing with " + f.split(/[\\/]/).pop() + ". Esc ends the comparison")
    }
    function stopCompare() { compareFile = "" }
    function seekRelative(s) { mpv.seekBy(s, Math.abs(s) < 2) }
    function mpvItem() { return mpv }
    // Used by the built-in self-test.
    function openPalette() { if (!palette.opened) palette.open() }
    function closePalette() { palette.close() }
    function openSettings(page) { settingsDialog.openAt(page) }
    function closeSettings() { settingsDialog.close() }
    property bool settingsOpen: settingsDialog.opened

    // ----- keyboard -------------------------------------------------------------
    // Every action, in the order the shortcut list and command palette show them.
    readonly property var actionList: [
        { id: "open", category: "File", name: "Open file…", keys: ["Ctrl+O"], run: openFileDialog },
        { id: "openFolder", category: "File", name: "Open folder…", keys: ["Ctrl+Shift+O"], run: openFolderDialog },
        { id: "openUrl", category: "File", name: "Open URL…", keys: ["Ctrl+U"], run: () => urlDialog.open() },
        { id: "loadSubs", category: "File", name: "Load subtitle file…", keys: [], run: openSubtitleDialog },
        { id: "nextFile", category: "File", name: "Next clip in folder", keys: ["PgDown"], run: () => openNext(1) },
        { id: "prevFile", category: "File", name: "Previous clip in folder", keys: ["PgUp"], run: () => openNext(-1) },

        { id: "play", category: "Playback", name: "Play / pause", keys: ["Space"], run: () => { rewindRate = 0; mpv.togglePause() } },
        { id: "frameNext", category: "Playback", name: "Next frame", keys: ["."], run: () => mpv.stepFrame(1) },
        { id: "framePrev", category: "Playback", name: "Previous frame", keys: [","], run: () => mpv.stepFrame(-1) },
        { id: "fwd5", category: "Playback", name: "Forward 5 seconds", keys: ["Right"], run: () => seekRelative(5) },
        { id: "back5", category: "Playback", name: "Back 5 seconds", keys: ["Left"], run: () => seekRelative(-5) },
        { id: "fwd1", category: "Playback", name: "Forward 1 second", keys: ["Shift+Right"], run: () => seekRelative(1) },
        { id: "back1", category: "Playback", name: "Back 1 second", keys: ["Shift+Left"], run: () => seekRelative(-1) },
        { id: "start", category: "Playback", name: "Go to start", keys: ["Home"], run: () => mpv.seekTo(0) },
        { id: "end", category: "Playback", name: "Go to end", keys: ["End"], run: () => mpv.seekTo(mpv.duration) },
        { id: "shuttleJ", category: "Playback", name: "Rewind (J)", keys: ["J"], run: () => shuttle("j") },
        { id: "shuttleK", category: "Playback", name: "Stop (K)", keys: ["K"], run: () => shuttle("k") },
        { id: "shuttleL", category: "Playback", name: "Play, faster each press (L)", keys: ["L"], run: () => shuttle("l") },
        { id: "faster", category: "Playback", name: "Faster", keys: ["]"], run: () => cycleSpeed(1) },
        { id: "slower", category: "Playback", name: "Slower", keys: ["["], run: () => cycleSpeed(-1) },
        { id: "normalSpeed", category: "Playback", name: "Normal speed", keys: ["="], run: resetSpeed },
        { id: "skipSilence", category: "Playback", name: "Skip silences", keys: ["Ctrl+Shift+K"], run: toggleSkipSilence },
        { id: "volUp", category: "Playback", name: "Volume up", keys: ["Up"], run: () => mpv.volume = Math.min(100, mpv.volume + 5) },
        { id: "volDown", category: "Playback", name: "Volume down", keys: ["Down"], run: () => mpv.volume = Math.max(0, mpv.volume - 5) },
        { id: "mute", category: "Playback", name: "Mute", keys: ["Ctrl+M"], run: () => mpv.muted = !mpv.muted },

        { id: "marker", category: "Review", name: "Add marker", keys: ["M"], run: addMarker },
        { id: "nextMarker", category: "Review", name: "Next marker", keys: ["Ctrl+Right"], run: () => jumpMarker(1) },
        { id: "prevMarker", category: "Review", name: "Previous marker", keys: ["Ctrl+Left"], run: () => jumpMarker(-1) },
        { id: "in", category: "Review", name: "Set In point", keys: ["I"], run: setIn },
        { id: "out", category: "Review", name: "Set Out point", keys: ["O"], run: setOut },
        { id: "clearInOut", category: "Review", name: "Clear In and Out", keys: ["X"], run: clearInOut },
        { id: "loop", category: "Review", name: "Loop In to Out", keys: ["Ctrl+L"], run: toggleLoop },
        { id: "rate1", category: "Review", name: "Rate 1 star", keys: ["1"], run: () => rate(1) },
        { id: "rate2", category: "Review", name: "Rate 2 stars", keys: ["2"], run: () => rate(2) },
        { id: "rate3", category: "Review", name: "Rate 3 stars", keys: ["3"], run: () => rate(3) },
        { id: "rate4", category: "Review", name: "Rate 4 stars", keys: ["4"], run: () => rate(4) },
        { id: "rate5", category: "Review", name: "Rate 5 stars", keys: ["5"], run: () => rate(5) },
        { id: "rate0", category: "Review", name: "Clear rating", keys: ["0"], run: () => rate(0) },
        { id: "zoomIn", category: "Review", name: "Zoom timeline in", keys: ["Ctrl+="], run: () => timeline.zoomBy(0.6) },
        { id: "zoomOut", category: "Review", name: "Zoom timeline out", keys: ["Ctrl+-"], run: () => timeline.zoomBy(1.6) },
        { id: "zoomReset", category: "Review", name: "Show whole timeline", keys: ["Ctrl+0"], run: () => timeline.resetZoom() },

        { id: "exportClip", category: "Export", name: "Export In to Out (lossless)", keys: ["Ctrl+E"], run: () => App.exportClip(true) },
        { id: "exportExact", category: "Export", name: "Export In to Out (frame-exact)", keys: ["Ctrl+Shift+E"], run: () => App.exportClip(false) },
        { id: "edl", category: "Export", name: "Export markers for DaVinci Resolve (EDL)", keys: [], run: () => App.exportMarkersEdl(mpv.fps) },
        { id: "csv", category: "Export", name: "Export markers as CSV", keys: [], run: () => App.exportMarkersCsv(mpv.fps) },
        { id: "chapters", category: "Export", name: "Copy markers as YouTube chapters", keys: [], run: () => App.copyYouTubeChapters(mpv.duration) },
        { id: "frameGrab", category: "Export", name: "Save current frame as PNG", keys: ["Ctrl+Shift+S"], run: grabFrame },
        { id: "transcribe", category: "Export", name: "Transcribe this clip", keys: [], run: () => { showTab(3); Transcript.start(App.currentFile) } },

        { id: "panels", category: "View", name: "Show or hide side panel", keys: ["H"], run: togglePanels },
        { id: "fullscreen", category: "View", name: "Full screen", keys: ["F", "F11"], run: toggleFullscreen },
        { id: "tabMarkers", category: "View", name: "Show markers", keys: ["Alt+1"], run: () => showTab(0) },
        { id: "tabClips", category: "View", name: "Show clips in folder", keys: ["Alt+2"], run: () => showTab(1) },
        { id: "tabInfo", category: "View", name: "Show media info", keys: ["Alt+3"], run: () => showTab(2) },
        { id: "tabTranscript", category: "View", name: "Show transcript", keys: ["Alt+4"], run: () => showTab(3) },
        { id: "tabScopes", category: "View", name: "Show video scopes", keys: ["Alt+5"], run: () => showTab(4) },
        { id: "palette", category: "View", name: "Search actions", keys: ["Ctrl+K"], run: () => palette.open() },
        { id: "shortcuts", category: "View", name: "Keyboard shortcuts", keys: ["?"], run: () => settingsDialog.openAt(4) },
        { id: "settings", category: "View", name: "Settings", keys: ["Ctrl+,"], run: () => settingsDialog.openAt(0) }
    ]
    function keysFor(a) {
        keymapRevision
        const o = App.setting("keys/" + a.id, "")
        if (o === "-") return []
        return o ? o.split("|") : a.keys
    }
    function keysLabel(a) { return keysFor(a).join("  ") }

    Instantiator {
        model: win.actionList
        delegate: Shortcut {
            required property var modelData
            sequences: win.keysFor(modelData)
            context: Qt.WindowShortcut
            enabled: !palette.opened && !settingsDialog.opened && !urlDialog.opened
            autoRepeat: ["frameNext", "framePrev", "fwd5", "back5", "fwd1", "back1", "volUp", "volDown"].indexOf(modelData.id) >= 0
            onActivated: modelData.run()
        }
    }
    // keyboard media keys
    Shortcut { sequences: ["Toggle Media Play/Pause", "Media Play", "Media Pause"]; context: Qt.WindowShortcut; enabled: mpv.loaded; onActivated: mpv.togglePause() }
    Shortcut { sequence: "Media Stop"; context: Qt.WindowShortcut; enabled: mpv.loaded; onActivated: mpv.paused = true }
    Shortcut { sequence: "Media Next"; context: Qt.WindowShortcut; onActivated: win.openNext(1) }
    Shortcut { sequence: "Media Previous"; context: Qt.WindowShortcut; onActivated: win.openNext(-1) }
    Shortcut {
        sequence: "Escape"
        enabled: !palette.opened && !settingsDialog.opened && (win.isFull || win.compareFile !== "")
        onActivated: { if (win.isFull) win.toggleFullscreen(); else win.stopCompare() }
    }

    Timer { // J rewind
        interval: 100; repeat: true; running: win.rewindRate > 0
        onTriggered: { if (mpv.position <= 0.05) { win.rewindRate = 0; return } mpv.seekBy(-0.1 * win.rewindRate * 2, false) }
    }
    Timer { // skip silences
        interval: 80; repeat: true
        running: win.skipSilence && mpv.loaded && !mpv.paused
        onTriggered: {
            const s = Media.silenceAt(mpv.position + 0.05)
            if (s.length === 2 && s[1] - mpv.position > 0.3) { win.silenceSaved += s[1] - mpv.position; mpv.seekTo(s[1], false) }
        }
    }
    Timer { id: idleTimer; interval: 2200; onTriggered: win.mouseRecently = false }
    Timer { // keep the comparison clip in step
        interval: 200; repeat: true; running: win.compareFile !== "" && compareLoader.item !== null
        onTriggered: {
            const b = compareLoader.item
            if (!b || !b.loaded) return
            if (b.paused !== mpv.paused) b.paused = mpv.paused
            if (Math.abs(b.speed - mpv.speed) > 0.001) b.speed = mpv.speed
            const want = Math.max(0, mpv.position + win.compareOffset)
            const drift = Math.abs(b.position - want)
            if ((mpv.paused && drift > 0.001) || (!mpv.paused && drift > 0.12)) b.seekTo(Math.min(want, b.duration), true)
        }
    }

    // ----- engine events ------------------------------------------------------------
    Connections {
        target: mpv
        function onErrorOccurred(message) { win.toast(message) }
        function onEndOfFile() {
            win.rewindRate = 0
            if (App.setting("autoAdvance", false) && App.nextInQueue(1)) Qt.callLater(() => win.openNext(1))
        }
        function onFileLoaded() { Media.analyse(App.currentFile, mpv.duration, mpv.hasVideo) }
        function onDurationChanged() { if (mpv.loaded) Media.analyse(App.currentFile, mpv.duration, mpv.hasVideo) }
        function onVideoInfoChanged() { if (mpv.loaded) Media.analyse(App.currentFile, mpv.duration, mpv.hasVideo) }
        function onVolumeChanged() { volumeSave.restart() }
    }
    Timer { id: volumeSave; interval: 800; onTriggered: if (App.setting("rememberVolume", true)) App.setSetting("volume", mpv.volume) }
    Connections {
        target: App
        function onMessage(text, revealPath) { win.toast(text, revealPath) }
        function onOpenRequested(file) {
            if (win.visibility === Window.Minimized) win.showNormal()
            win.raise(); win.requestActivate()
            if (file) win.openMedia(file)
        }
    }
    Connections {
        target: Transcript
        function onFinished(ok, message) { win.toast(message) }
    }

    Component.onCompleted: {
        const g = App.setting("window", "")
        if (g) {
            const p = g.split(",").map(Number)
            if (p.length >= 5 && p[2] >= minimumWidth && p[3] >= minimumHeight) {
                x = p[0]; y = p[1]; width = p[2]; height = p[3]
                if (p[4] === 1) Qt.callLater(() => win.showMaximized())
            }
        }
        if (App.setting("rememberVolume", true)) mpv.volume = App.setting("volume", 100)
        mpv.setMpvProperty("hwdec", App.setting("hwdec", true) ? "auto-safe" : "no")
        Transcript.model = App.setting("whisperModel", "base.en")
    }
    // Look for a newer build a few seconds after start, and fetch it in the background.
    Timer {
        interval: 4000; running: Updater.supported && App.setting("autoUpdate", true); repeat: false
        onTriggered: Updater.check(true)
    }
    Connections {
        target: Updater
        function onChanged() {
            if (Updater.supported && Updater.state === "available" && App.setting("autoUpdate", true)) Updater.download()
        }
    }
    onClosing: {
        if (mpv.loaded) App.savePosition(mpv.position, mpv.duration)
        const maxed = visibility === Window.Maximized || (isFull && wasMaximized)
        const old = String(App.setting("window", "")).split(",")
        const geom = (!isFull && visibility !== Window.Maximized) || old.length < 5 ? [x, y, width, height] : old.slice(0, 4)
        App.setSetting("window", geom.concat([maxed ? 1 : 0]).join(","))
    }

    FileDialog {
        id: fileDialog
        title: "Open media"
        nameFilters: ["Media files (*.mp4 *.mov *.mkv *.webm *.avi *.m4v *.mts *.m2ts *.ts *.wmv *.flv *.mxf *.mpg *.mpeg *.3gp *.mp3 *.wav *.flac *.m4a *.aac *.ogg *.opus *.aiff *.wma)", "All files (*)"]
        onAccepted: win.openMedia(selectedFile)
    }
    FolderDialog { id: folderDialog; title: "Open folder"; onAccepted: win.openMedia(selectedFolder) }
    FileDialog {
        id: subDialog
        title: "Load subtitles"
        nameFilters: ["Subtitles (*.srt *.ass *.ssa *.vtt *.sub)", "All files (*)"]
        onAccepted: { mpv.addSubtitle(App.localPath(selectedFile)); win.toast("Subtitles loaded") }
    }

    // ----- layout -------------------------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // header
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            visible: !win.isFull
            color: Theme.chrome
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.line }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14; anchors.rightMargin: 8
                spacing: 10
                Image { source: "qrc:/Slate/assets/slate-small-64.png"; sourceSize: Qt.size(22, 22); Layout.preferredWidth: 22; Layout.preferredHeight: 22 }
                Column {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 640
                    spacing: 1
                    Text {
                        width: parent.width
                        text: App.currentName || "Slate"
                        color: Theme.ink; font.pixelSize: Theme.fontBody; font.weight: Font.DemiBold
                        elide: Text.ElideMiddle
                    }
                    Text {
                        visible: App.currentFile !== ""
                        width: parent.width
                        text: App.currentFile.substring(0, App.currentFile.length - App.currentName.length).replace(/[\\/]$/, "")
                        color: Theme.ink3; font.pixelSize: 11
                        elide: Text.ElideMiddle
                    }
                }
                Row {
                    visible: App.queue.length > 1
                    spacing: 0
                    Btn { glyph: "prev"; iconSize: 15; implicitWidth: 28; tip: "Previous clip"; keys: "PgUp"; enabled: App.queueIndex > 0; onClicked: win.openNext(-1) }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 64; horizontalAlignment: Text.AlignHCenter
                        text: (App.queueIndex + 1) + " of " + App.queue.length
                        color: Theme.ink2; font.pixelSize: 12
                    }
                    Btn { glyph: "next"; iconSize: 15; implicitWidth: 28; tip: "Next clip"; keys: "PgDown"; enabled: App.queueIndex < App.queue.length - 1; onClicked: win.openNext(1) }
                }
                Item { Layout.fillWidth: true }

                // update chip: appears only when a newer build exists
                Btn {
                    id: updateChip
                    visible: ["available", "downloading", "ready"].indexOf(Updater.state) >= 0
                    primary: Updater.state === "ready"
                    active: Updater.state !== "ready"
                    glyph: Updater.state === "ready" ? "loop" : "download"
                    text: Updater.state === "ready" ? "Restart to update"
                          : (Updater.state === "downloading" ? "Downloading update " + Math.round(Updater.progress * 100) + "%" : "Update to " + Updater.latestVersion)
                    tip: Updater.state === "ready" ? "Slate closes, updates and reopens in a few seconds" : "A newer version of Slate is available"
                    enabled: Updater.state !== "downloading"
                    onClicked: Updater.state === "ready" ? Updater.installAndRestart() : Updater.download()
                }

                Rectangle {
                    Layout.preferredWidth: 240
                    Layout.preferredHeight: 30
                    radius: Theme.radius
                    color: sbMa.containsMouse ? Theme.hover : Theme.raise
                    border.color: Theme.line
                    Icon { x: 9; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 15; color: Theme.ink3 }
                    Text { x: 32; anchors.verticalCenter: parent.verticalCenter; text: "Search actions"; color: Theme.ink3; font.pixelSize: 12 }
                    Rectangle {
                        anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                        width: kk.implicitWidth + 10; height: 18; radius: 4
                        color: Theme.bg; border.color: Theme.lineStrong
                        Text { id: kk; anchors.centerIn: parent; text: "Ctrl K"; color: Theme.ink3; font.pixelSize: 10 }
                    }
                    MouseArea { id: sbMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: palette.open() }
                }
                Btn { glyph: "open"; tip: "Open file"; keys: "Ctrl+O"; onClicked: fileDialog.open() }
                Btn { glyph: "sidebar"; tip: win.panelsVisible ? "Hide side panel" : "Show side panel"; keys: "H"; active: win.panelsVisible; onClicked: win.togglePanels() }
                Btn { glyph: "settings"; tip: "Settings"; keys: "Ctrl+,"; onClicked: settingsDialog.openAt(0) }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // ---- picture ----
            Rectangle {
                id: videoArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: mpv.loaded && mpv.hasVideo ? "#000000" : Theme.bg
                clip: true

                Row {
                    anchors.fill: parent
                    MpvObject {
                        id: mpv
                        width: win.compareFile ? parent.width / 2 : parent.width
                        height: parent.height
                    }
                    Loader {
                        id: compareLoader
                        active: win.compareFile !== ""
                        width: active ? parent.width / 2 : 0
                        height: parent.height
                        sourceComponent: MpvObject {
                            muted: true
                            Component.onCompleted: open(win.compareFile, Math.max(0, mpv.position))
                        }
                    }
                }
                Row {
                    visible: win.compareFile !== ""
                    anchors.fill: parent
                    Repeater {
                        model: 2
                        delegate: Item {
                            required property int index
                            width: parent.width / 2; height: parent.height
                            Rectangle {
                                x: 12; y: 12
                                width: cl.implicitWidth + 16; height: 24; radius: 4
                                color: Qt.rgba(0, 0, 0, 0.6)
                                Text {
                                    id: cl; anchors.centerIn: parent
                                    text: (index === 0 ? "A   " + App.currentName : "B   " + win.compareFile.split(/[\\/]/).pop())
                                    color: "white"; font.pixelSize: 12
                                }
                            }
                        }
                    }
                }

                AudioView { anchors.fill: parent; mpv: mpv; visible: mpv.loaded && !mpv.hasVideo }
                EmptyState { anchors.fill: parent; win: win; visible: !mpv.loaded && App.currentFile === "" }
                Column {
                    anchors.centerIn: parent
                    visible: !mpv.loaded && App.currentFile !== ""
                    spacing: 10
                    BusyIndicator { anchors.horizontalCenter: parent.horizontalCenter; running: parent.visible; implicitWidth: 36; implicitHeight: 36 }
                    Text { text: "Opening " + App.currentName; color: Theme.ink3; font.pixelSize: 12 }
                }

                Row {
                    x: 12; y: 12
                    spacing: 6
                    visible: mpv.loaded && win.compareFile === "" && (win.chromeVisible || win.skipSilence)
                    component Chip: Rectangle {
                        property alias text: t.text
                        property color tone: "white"
                        width: t.implicitWidth + 14; height: 22; radius: 4
                        color: Qt.rgba(0, 0, 0, 0.55)
                        Text { id: t; anchors.centerIn: parent; color: parent.tone; font.pixelSize: 11 }
                    }
                    Chip { visible: mpv.loopA >= 0; text: "Looping In → Out" }
                    Chip { visible: Math.abs(mpv.speed - 1) > 0.001; text: mpv.speed + "×" }
                    Chip { visible: win.skipSilence; text: "Skipping silences" + (win.silenceSaved >= 1 ? " · " + App.formatClock(win.silenceSaved) + " saved" : "") }
                    Chip { visible: Media.probe.vfr === true; tone: Theme.warn; text: "Variable frame rate" }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    enabled: mpv.loaded
                    onPositionChanged: { win.mouseRecently = true; idleTimer.restart() }
                    onClicked: mpv.togglePause()
                    onDoubleClicked: { mpv.togglePause(); win.toggleFullscreen() }
                    onWheel: (w) => mpv.volume = Math.max(0, Math.min(100, mpv.volume + (w.angleDelta.y > 0 ? 5 : -5)))
                    cursorShape: win.isFull && !win.mouseRecently ? Qt.BlankCursor : Qt.ArrowCursor
                }

                Btn {
                    visible: win.compareFile !== ""
                    anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 10
                    flat: false; glyph: "close"; text: "End comparison"; keys: "Esc"
                    onClicked: win.stopCompare()
                }

                DropArea {
                    id: drop
                    anchors.fill: parent
                    onDropped: (d) => { if (d.hasUrls) win.openMedia(d.urls[0]) }
                    Rectangle {
                        anchors.fill: parent; anchors.margins: 14
                        visible: drop.containsDrag
                        color: Qt.rgba(0.31, 0.55, 1, 0.08); radius: Theme.radiusLg
                        border.color: Theme.accent; border.width: 2
                        Column {
                            anchors.centerIn: parent; spacing: 10
                            Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "drop"; size: 34; color: Theme.accent }
                            Text { text: "Drop to open"; color: Theme.ink; font.pixelSize: 16 }
                        }
                    }
                }

                // full-screen controls float over the picture
                Item {
                    id: overlayControls
                    visible: win.isFull
                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                    height: 200
                    opacity: win.chromeVisible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 220 } }
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0; color: "transparent" }
                            GradientStop { position: 0.35; color: Qt.rgba(0, 0, 0, 0.6) }
                            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.88) }
                        }
                    }
                    HoverHandler { onHoveredChanged: if (hovered) { win.mouseRecently = true; idleTimer.stop() } else idleTimer.restart() }
                }

                Toast {
                    id: toastItem
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: win.isFull ? 160 : 20
                }
            }

            // ---- side panel ----
            Rectangle {
                id: side
                Layout.preferredWidth: 340
                Layout.fillHeight: true
                visible: win.panelsVisible && !win.isFull && App.currentFile !== ""
                color: Theme.panel
                Rectangle { width: 1; height: parent.height; color: Theme.line }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 1
                    spacing: 0
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        color: Theme.panel
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.line }
                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            Repeater {
                                model: [
                                    { icon: "marker", tip: "Markers", keys: "Alt+1", badge: App.markers.count },
                                    { icon: "list", tip: "Clips in this folder", keys: "Alt+2", badge: App.queue.length > 1 ? App.queue.length : 0 },
                                    { icon: "info", tip: "Media info", keys: "Alt+3", badge: Media.probe.vfr === true ? -1 : 0 },
                                    { icon: "transcript", tip: "Transcript", keys: "Alt+4", badge: 0 },
                                    { icon: "scope", tip: "Video scopes", keys: "Alt+5", badge: 0 }
                                ]
                                delegate: AbstractButton {
                                    id: tabBtn
                                    required property var modelData
                                    required property int index
                                    width: 56; height: 34
                                    focusPolicy: Qt.NoFocus
                                    hoverEnabled: true
                                    onClicked: win.sideTab = index
                                    background: Rectangle {
                                        radius: Theme.radius
                                        color: win.sideTab === tabBtn.index ? Theme.hover : (tabBtn.hovered ? Theme.raise : "transparent")
                                    }
                                    contentItem: Item {
                                        Icon { anchors.centerIn: parent; name: tabBtn.modelData.icon; size: 18; color: win.sideTab === tabBtn.index ? Theme.ink : Theme.ink2 }
                                        Rectangle {
                                            visible: tabBtn.modelData.badge !== 0
                                            x: parent.width / 2 + 5; y: 2
                                            width: tabBtn.modelData.badge < 0 ? 7 : Math.max(16, bl.implicitWidth + 8)
                                            height: tabBtn.modelData.badge < 0 ? 7 : 15
                                            radius: height / 2
                                            color: tabBtn.modelData.badge < 0 ? Theme.warn : Theme.press
                                            Text { id: bl; visible: tabBtn.modelData.badge > 0; anchors.centerIn: parent; text: tabBtn.modelData.badge; color: Theme.ink2; font.pixelSize: 9 }
                                        }
                                    }
                                    Tip { visible: tabBtn.hovered; text: tabBtn.modelData.tip; keys: tabBtn.modelData.keys }
                                }
                            }
                        }
                    }
                    StackLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        currentIndex: win.sideTab
                        MarkerPanel { mpv: mpv; win: win }
                        ClipsPanel { win: win }
                        InfoPanel { mpv: mpv }
                        TranscriptPanel { mpv: mpv; win: win }
                        ScopesPanel { mpv: mpv; shown: side.visible && win.sideTab === 4 }
                    }
                }
            }
        }

        // Docked timeline and transport; in full screen they move over the picture.
        Item {
            id: dock
            Layout.fillWidth: true
            Layout.preferredHeight: win.isFull || App.currentFile === "" ? 0 : controls.implicitHeight + 1
            visible: !win.isFull && App.currentFile !== ""
            Rectangle { width: parent.width; height: 1; color: Theme.line }
        }
    }

    Column {
        id: controls
        parent: win.isFull ? overlayControls : dock
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.bottomMargin: win.isFull ? 8 : 0
        Timeline { id: timeline; width: parent.width; mpv: mpv; overlay: win.isFull }
        TransportBar { id: transport; width: parent.width; mpv: mpv; win: win; overlay: win.isFull }
    }

    CommandPalette {
        id: palette
        actions: win.actionList.map(a => ({ name: a.name, category: a.category, keys: win.keysLabel(a), run: a.run }))
    }
    SettingsDialog { id: settingsDialog; win: win }
    OpenUrlDialog { id: urlDialog; onAccepted: (u) => win.openMedia(u) }
}
