import QtQuick
import Take
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs


ApplicationWindow {
    id: win
    width: 1360
    height: 820
    minimumWidth: 900
    minimumHeight: 560
    visible: true
    color: Theme.bg
    title: App.currentName ? App.currentName + " · Take" : "Take"

    property bool panelsVisible: true
    property bool paletteOpen: palette.opened
    readonly property bool isFull: visibility === Window.FullScreen
    property bool chromeVisible: !isFull || mouseRecently
    property bool mouseRecently: true
    property int rewindRate: 0          // J held: 1, 2, 4, 8
    readonly property var speeds: [0.25, 0.5, 0.75, 1, 1.25, 1.5, 2, 3, 4]

    // ----- actions used by shortcuts, buttons and the palette ---------------
    function toast(msg, path) { toastItem.show(msg, path) }

    function openMedia(target) {
        if (mpv.loaded) App.savePosition(mpv.position, mpv.duration)
        const f = App.prepareOpen(target)
        if (!f) return
        const resume = App.resumePosition(f)
        mpv.open(f, resume)
        if (resume > 0) toast("Resumed at " + App.formatClock(resume) + ". Press Home to start from the beginning")
    }
    function openNext(dir) {
        const f = App.nextInQueue(dir)
        if (f) openMedia(f); else toast(dir > 0 ? "Last file in this folder" : "First file in this folder")
    }
    function openPalette() { if (!palette.opened) palette.open() }
    function closePalette() { palette.close() }
    function addMarker() {
        if (!mpv.loaded) return
        App.markers.add(mpv.position, 0, "Marker")
        toast("Marker at " + fmt(mpv.position) + ". Double-click it in the list to type a note")
    }
    function setIn() { if (mpv.loaded) { App.inPoint = mpv.position; toast("In " + fmt(App.inPoint)); syncLoop() } }
    function setOut() { if (mpv.loaded) { App.outPoint = mpv.position; toast("Out " + fmt(App.outPoint)); syncLoop() } }
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
        toast("Speed " + speeds[i] + "×, pitch kept")
    }
    function resetSpeed() { mpv.speed = 1; toast("Speed 1×") }
    function shuttle(key) {
        // J / K / L like editing apps. Repeated L plays faster; J rewinds in steps.
        if (key === "k") { rewindRate = 0; mpv.paused = true; mpv.speed = 1; return }
        if (key === "l") {
            rewindRate = 0
            if (mpv.paused) { mpv.speed = 1; mpv.paused = false }
            else mpv.speed = Math.min(8, mpv.speed >= 1 ? mpv.speed * 2 : 1)
            toast("Play " + mpv.speed + "×")
            return
        }
        mpv.paused = true
        rewindRate = rewindRate === 0 ? 1 : Math.min(8, rewindRate * 2)
        toast("Rewind " + rewindRate + "×  (K stops)")
    }
    function grabFrame() {
        if (!mpv.loaded || !mpv.hasVideo) { toast("No video frame to save"); return }
        const p = App.frameGrabPath(mpv.frame)
        if (mpv.screenshot(p)) toast("Saved frame " + mpv.frame, p); else toast("Couldn't save the frame")
    }
    function toggleFullscreen() { win.visibility = isFull ? Window.Windowed : Window.FullScreen }
    function fmt(t) { return mpv.hasVideo && mpv.fps > 0 ? App.formatTimecode(t, mpv.fps) : App.formatClock(t) }
    function jumpMarker(dir) {
        const t = dir > 0 ? App.markers.nextAfter(mpv.position) : App.markers.prevBefore(mpv.position)
        if (t >= 0) { mpv.paused = true; mpv.seekTo(t, true) } else toast(dir > 0 ? "No marker after this point" : "No marker before this point")
    }

    readonly property var actionList: [
        { name: "Open file…", keys: "Ctrl+O", run: () => fileDialog.open() },
        { name: "Open folder…", keys: "", run: () => folderDialog.open() },
        { name: "Play / pause", keys: "Space", run: () => mpv.togglePause() },
        { name: "Next frame", keys: ".", run: () => mpv.stepFrame(1) },
        { name: "Previous frame", keys: ",", run: () => mpv.stepFrame(-1) },
        { name: "Add marker", keys: "M", run: addMarker },
        { name: "Next marker", keys: "Ctrl+→", run: () => jumpMarker(1) },
        { name: "Previous marker", keys: "Ctrl+←", run: () => jumpMarker(-1) },
        { name: "Set In point", keys: "I", run: setIn },
        { name: "Set Out point", keys: "O", run: setOut },
        { name: "Clear In and Out", keys: "X", run: clearInOut },
        { name: "Loop In to Out", keys: "Ctrl+L", run: toggleLoop },
        { name: "Export In→Out as new clip (lossless)", keys: "Ctrl+E", run: () => App.exportClip(true) },
        { name: "Export In→Out frame-exact (re-encode)", keys: "Ctrl+Shift+E", run: () => App.exportClip(false) },
        { name: "Export markers as EDL (DaVinci Resolve)", keys: "", run: () => App.exportMarkersEdl(mpv.fps) },
        { name: "Export markers as CSV", keys: "", run: () => App.exportMarkersCsv(mpv.fps) },
        { name: "Copy markers as YouTube chapters", keys: "", run: () => App.copyYouTubeChapters(mpv.duration) },
        { name: "Save current frame as PNG", keys: "Ctrl+Shift+S", run: grabFrame },
        { name: "Faster", keys: "]", run: () => cycleSpeed(1) },
        { name: "Slower", keys: "[", run: () => cycleSpeed(-1) },
        { name: "Normal speed", keys: "=", run: resetSpeed },
        { name: "Next file in folder", keys: "PgDown", run: () => openNext(1) },
        { name: "Previous file in folder", keys: "PgUp", run: () => openNext(-1) },
        { name: "Hide or show side panels", keys: "H", run: () => panelsVisible = !panelsVisible },
        { name: "Full screen", keys: "F", run: toggleFullscreen },
        { name: "Mute", keys: "Ctrl+M", run: () => mpv.muted = !mpv.muted },
        { name: "Keyboard shortcuts", keys: "?", run: () => helpDialog.open() }
    ]

    // ----- keyboard ----------------------------------------------------------
    component Key: Shortcut { context: Qt.WindowShortcut; enabled: !palette.opened }
    Key { sequence: "Space"; onActivated: { rewindRate = 0; mpv.togglePause() } }
    Key { sequence: "."; onActivated: mpv.stepFrame(1) }
    Key { sequence: ","; onActivated: mpv.stepFrame(-1) }
    Key { sequence: "Right"; onActivated: mpv.seekBy(5) }
    Key { sequence: "Left"; onActivated: mpv.seekBy(-5) }
    Key { sequence: "Shift+Right"; onActivated: mpv.seekBy(1, true) }
    Key { sequence: "Shift+Left"; onActivated: mpv.seekBy(-1, true) }
    Key { sequence: "Ctrl+Right"; onActivated: jumpMarker(1) }
    Key { sequence: "Ctrl+Left"; onActivated: jumpMarker(-1) }
    Key { sequence: "Home"; onActivated: mpv.seekTo(0) }
    Key { sequence: "End"; onActivated: mpv.seekTo(mpv.duration) }
    Key { sequence: "J"; onActivated: shuttle("j") }
    Key { sequence: "K"; onActivated: shuttle("k") }
    Key { sequence: "L"; onActivated: shuttle("l") }
    Key { sequence: "I"; onActivated: setIn() }
    Key { sequence: "O"; onActivated: setOut() }
    Key { sequence: "X"; onActivated: clearInOut() }
    Key { sequence: "M"; onActivated: addMarker() }
    Key { sequence: "H"; onActivated: panelsVisible = !panelsVisible }
    Key { sequence: "F"; onActivated: toggleFullscreen() }
    Key { sequence: "F11"; onActivated: toggleFullscreen() }
    Key { sequence: "Escape"; onActivated: if (isFull) toggleFullscreen() }
    Key { sequence: "]"; onActivated: cycleSpeed(1) }
    Key { sequence: "["; onActivated: cycleSpeed(-1) }
    Key { sequence: "="; onActivated: resetSpeed() }
    Key { sequence: "Up"; onActivated: mpv.volume = Math.min(130, mpv.volume + 5) }
    Key { sequence: "Down"; onActivated: mpv.volume = Math.max(0, mpv.volume - 5) }
    Key { sequence: "Ctrl+M"; onActivated: mpv.muted = !mpv.muted }
    Key { sequence: "PgDown"; onActivated: openNext(1) }
    Key { sequence: "PgUp"; onActivated: openNext(-1) }
    Key { sequence: "Ctrl+L"; onActivated: toggleLoop() }
    Key { sequence: "Ctrl+E"; onActivated: App.exportClip(true) }
    Key { sequence: "Ctrl+Shift+E"; onActivated: App.exportClip(false) }
    Key { sequence: "Ctrl+Shift+S"; onActivated: grabFrame() }
    Key { sequence: "Ctrl+O"; onActivated: fileDialog.open() }
    Key { sequence: "?"; onActivated: helpDialog.open() }
    Shortcut { sequence: "Ctrl+K"; onActivated: palette.opened ? palette.close() : palette.open() }

    Timer { // J rewind
        interval: 100; repeat: true; running: win.rewindRate > 0
        onTriggered: { if (mpv.position <= 0.05) { win.rewindRate = 0; return } mpv.seekBy(-0.1 * win.rewindRate * 2, false) }
    }
    Timer { id: idleTimer; interval: 2500; onTriggered: win.mouseRecently = false }

    // ----- engine --------------------------------------------------------------

    Connections {
        target: mpv
        function onErrorOccurred(message) { toast(message) }
        function onEndOfFile() { win.rewindRate = 0 }
    }
    Connections {
        target: App
        function onMessage(text, revealPath) { toast(text, revealPath) }
    }
    onClosing: if (mpv.loaded) App.savePosition(mpv.position, mpv.duration)

    FileDialog {
        id: fileDialog
        title: "Open media"
        nameFilters: ["Media files (*.mp4 *.mov *.mkv *.webm *.avi *.m4v *.mts *.m2ts *.ts *.wmv *.flv *.mxf *.mpg *.mp3 *.wav *.flac *.m4a *.aac *.ogg *.opus *.aiff)", "All files (*)"]
        onAccepted: openMedia(selectedFile)
    }
    FolderDialog {
        id: folderDialog
        title: "Open folder"
        onAccepted: openMedia(selectedFolder)
    }

    // ----- layout --------------------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // header
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            visible: !win.isFull
            color: Theme.panel
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.line }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14; anchors.rightMargin: 10
                spacing: 12
                Rectangle { width: 12; height: 12; radius: 6; color: Theme.accent }
                Text { text: "Take"; color: Theme.ink; font.pixelSize: 14; font.weight: Font.DemiBold }
                Text {
                    Layout.fillWidth: true
                    text: App.currentFile
                    color: Theme.muted; font.pixelSize: 12; font.family: Theme.mono
                    elide: Text.ElideMiddle
                }
                Text {
                    visible: App.queue.length > 1
                    text: (App.queueIndex + 1) + " of " + App.queue.length
                    color: Theme.muted; font.pixelSize: 12
                }
                IconButton { text: "Open"; tip: "Open a file  (Ctrl+O)"; onClicked: fileDialog.open() }
                IconButton { text: "Search actions   Ctrl K"; tip: "Find any action by name"; onClicked: palette.open() }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // video area
            Rectangle {
                id: videoArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#08090b"

                MpvObject { id: mpv; anchors.fill: parent }

                // audio-only placeholder
                Column {
                    anchors.centerIn: parent
                    visible: mpv.loaded && !mpv.hasVideo
                    spacing: 8
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "♪"; color: Theme.cool; font.pixelSize: 64 }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: App.currentName; color: Theme.ink; font.pixelSize: 16 }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Audio file · waveform view arrives in Phase 1"; color: Theme.muted; font.pixelSize: 12 }
                }

                // empty state
                Column {
                    anchors.centerIn: parent
                    visible: !mpv.loaded && App.currentFile === ""
                    spacing: 14
                    width: Math.min(520, parent.width - 40)
                    Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "Drop a clip, folder or audio file here"; color: Theme.ink; font.pixelSize: 20 }
                    Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "or press Ctrl+O to open, Ctrl+K to search actions, ? for shortcuts"; color: Theme.muted; font.pixelSize: 13 }
                    Text { visible: App.recentFiles.length > 0; text: "Recent"; color: Theme.muted; font.pixelSize: 11; topPadding: 10 }
                    Repeater {
                        model: App.recentFiles.slice(0, 6)
                        delegate: Text {
                            required property string modelData
                            width: parent.width
                            text: modelData; elide: Text.ElideMiddle
                            color: recentMouse.containsMouse ? Theme.accent : Theme.ink
                            font.pixelSize: 13
                            MouseArea { id: recentMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.openMedia(modelData) }
                        }
                    }
                }

                // format chips
                Row {
                    x: 14; y: 12
                    spacing: 6
                    visible: mpv.loaded && mpv.hasVideo && win.chromeVisible
                    component Chip: Rectangle {
                        property alias text: t.text
                        width: t.implicitWidth + 12; height: 20; radius: 4
                        color: Qt.rgba(0, 0, 0, 0.6); border.color: Qt.rgba(1, 1, 1, 0.12)
                        Text { id: t; anchors.centerIn: parent; color: Theme.ink; font.pixelSize: 11; font.family: Theme.mono }
                    }
                    Chip { visible: mpv.info.width !== undefined; text: mpv.info.width + "×" + mpv.info.height }
                    Chip { visible: mpv.fps > 0; text: mpv.fps.toFixed(3).replace(/\.?0+$/, "") + " fps" }
                    Chip { visible: mpv.info.videoCodec !== undefined; text: String(mpv.info.videoCodec).split(" ")[0] }
                    Chip { visible: mpv.loopA >= 0; text: "LOOP" }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    onPositionChanged: { win.mouseRecently = true; idleTimer.restart() }
                    onClicked: if (mpv.loaded) mpv.togglePause()
                    onDoubleClicked: { mpv.togglePause(); win.toggleFullscreen() }
                    cursorShape: win.isFull && !win.mouseRecently ? Qt.BlankCursor : Qt.ArrowCursor
                }

                DropArea {
                    anchors.fill: parent
                    onDropped: (drop) => { if (drop.hasUrls) win.openMedia(drop.urls[0]) }
                    Rectangle {
                        anchors.fill: parent; anchors.margins: 12
                        visible: parent.containsDrag
                        color: Qt.rgba(1, 0.6, 0.24, 0.08); radius: 10
                        border.color: Theme.accent; border.width: 2
                        Text { anchors.centerIn: parent; text: "Drop to open"; color: Theme.ink; font.pixelSize: 18 }
                    }
                }

                Toast { id: toastItem; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 18 }
            }

            // side panel
            Rectangle {
                Layout.preferredWidth: 320
                Layout.fillHeight: true
                visible: win.panelsVisible && !win.isFull
                color: Theme.panel
                Rectangle { width: 1; height: parent.height; color: Theme.line }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 1
                    spacing: 0
                    TabBar {
                        id: tabs
                        Layout.fillWidth: true
                        background: Rectangle { color: Theme.panel; Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.line } }
                        component Tab: TabButton {
                            id: tb
                            focusPolicy: Qt.NoFocus
                            contentItem: Text { text: tb.text; color: tb.checked ? Theme.ink : Theme.muted; font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter }
                            background: Rectangle { color: "transparent"; Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; color: tb.checked ? Theme.accent : "transparent" } }
                        }
                        Tab { text: "Markers" + (App.markers.count ? " (" + App.markers.count + ")" : "") }
                        Tab { text: "Info" }
                        Tab { text: "Folder" + (App.queue.length > 1 ? " (" + App.queue.length + ")" : "") }
                    }
                    StackLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        currentIndex: tabs.currentIndex
                        MarkerPanel { mpv: mpv }
                        InfoPanel { mpv: mpv }
                        ListView {
                            clip: true
                            model: App.queue
                            ScrollBar.vertical: ScrollBar {}
                            delegate: Rectangle {
                                required property string modelData
                                required property int index
                                width: ListView.view.width; height: 34
                                color: index === App.queueIndex ? Theme.raise : (qh.hovered ? Qt.rgba(1, 1, 1, 0.03) : "transparent")
                                Rectangle { visible: index === App.queueIndex; width: 2; height: parent.height; color: Theme.accent }
                                HoverHandler { id: qh }
                                Text {
                                    x: 12; width: parent.width - 24; anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.split(/[\\/]/).pop(); elide: Text.ElideRight
                                    color: Theme.ink; font.pixelSize: 13
                                }
                                MouseArea { anchors.fill: parent; onClicked: win.openMedia(modelData) }
                            }
                        }
                    }
                }
            }
        }

        TransportBar {
            Layout.fillWidth: true
            visible: win.chromeVisible
            mpv: mpv
            panelsVisible: win.panelsVisible
            onTogglePanels: win.panelsVisible = !win.panelsVisible
            onToggleFullscreen: win.toggleFullscreen()
            onAddMarker: win.addMarker()
            onSetIn: win.setIn()
            onSetOut: win.setOut()
            onToggleLoop: win.toggleLoop()
            onCycleSpeed: (dir) => win.cycleSpeed(dir)
        }
        Timeline { Layout.fillWidth: true; visible: win.chromeVisible; mpv: mpv }
    }

    CommandPalette { id: palette; actions: win.actionList }

    Dialog {
        id: helpDialog
        title: "Keyboard shortcuts"
        modal: true
        anchors.centerIn: parent
        width: Math.min(Math.max(560, implicitContentWidth + leftPadding + rightPadding), win.width - 40)
        footer: Item {
            implicitHeight: 56
            IconButton { text: "Close"; anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; onClicked: helpDialog.close() }
        }
        background: Rectangle { color: Theme.panel; border.color: Theme.line; radius: 10 }
        header: Text { text: "Keyboard shortcuts"; color: Theme.ink; font.pixelSize: 16; font.weight: Font.DemiBold; padding: 16 }
        GridLayout {
            columns: 2; columnSpacing: 24; rowSpacing: 6
            Repeater {
                model: win.actionList.filter(a => a.keys.length > 0)
                delegate: Text {
                    required property var modelData
                    text: "<font color='" + Theme.muted + "'>" + modelData.keys + "</font>&nbsp;&nbsp;" + modelData.name
                    textFormat: Text.RichText
                    color: Theme.ink; font.pixelSize: 12
                }
            }
            Text { text: "<font color='" + Theme.muted + "'>← →</font>&nbsp;&nbsp;Back / forward 5 s (Shift: 1 s)"; textFormat: Text.RichText; color: Theme.ink; font.pixelSize: 12 }
            Text { text: "<font color='" + Theme.muted + "'>J K L</font>&nbsp;&nbsp;Rewind / stop / play faster"; textFormat: Text.RichText; color: Theme.ink; font.pixelSize: 12 }
        }
    }
}
