import QtQuick
import Take
import QtQuick.Controls
import QtQuick.Layouts


Rectangle {
    id: bar
    required property var mpv
    property bool panelsVisible: true
    signal togglePanels()
    signal toggleFullscreen()
    signal addMarker()
    signal setIn()
    signal setOut()
    signal toggleLoop()
    signal cycleSpeed(int dir)

    implicitHeight: 52
    color: Theme.panel
    Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Theme.line }

    readonly property bool loopOn: mpv.loopA >= 0
    readonly property bool canLoop: App.inPoint >= 0 && App.outPoint > App.inPoint

    function timeText() {
        if (!mpv.loaded) return "--:--:--:--"
        return mpv.hasVideo && mpv.fps > 0 ? App.formatTimecode(mpv.position, mpv.fps)
                                           : App.formatClock(mpv.position) + "." + ("00" + Math.floor((mpv.position % 1) * 1000)).slice(-3)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 6

        Column {
            Layout.minimumWidth: 168
            Text { text: bar.timeText(); color: Theme.ink; font.family: Theme.mono; font.pixelSize: 20 }
            Text {
                color: Theme.muted; font.family: Theme.mono; font.pixelSize: 11
                text: !mpv.loaded ? "nothing loaded"
                      : (mpv.hasVideo && mpv.fps > 0 ? "frame " + mpv.frame + " · " + mpv.fps.toFixed(3).replace(/\.?0+$/, "") + " fps" : "audio")
                      + " · " + App.formatClock(mpv.duration)
            }
        }
        IconButton { text: "◀|"; tip: "Previous frame  ( , )"; enabled: mpv.loaded; onClicked: mpv.stepFrame(-1) }
        IconButton { text: mpv.paused || !mpv.loaded ? "▶" : "❚❚"; primary: true; implicitWidth: 46; tip: "Play / pause  (Space)"; enabled: mpv.loaded; onClicked: mpv.togglePause() }
        IconButton { text: "|▶"; tip: "Next frame  ( . )"; enabled: mpv.loaded; onClicked: mpv.stepFrame(1) }
        Rectangle { width: 1; height: 22; color: Theme.line; Layout.leftMargin: 4; Layout.rightMargin: 4 }
        IconButton {
            text: (Number.isInteger(mpv.speed) ? mpv.speed.toFixed(1) : String(Math.round(mpv.speed * 100) / 100)) + "×"
            tip: "Speed. Click to go faster, right-click slower  ( [ ] , = resets )"
            implicitWidth: 52
            onClicked: bar.cycleSpeed(1)
            TapHandler { acceptedButtons: Qt.RightButton; onTapped: bar.cycleSpeed(-1) }
        }
        IconButton { text: "Loop"; checkable: false; checked: bar.loopOn; enabled: bar.canLoop || bar.loopOn; tip: "Loop between In and Out  (Ctrl+L)"; onClicked: bar.toggleLoop() }
        Rectangle { width: 1; height: 22; color: Theme.line; Layout.leftMargin: 4; Layout.rightMargin: 4 }
        IconButton { text: "In"; tip: "Mark In  (I)"; enabled: mpv.loaded; onClicked: bar.setIn() }
        IconButton { text: "Out"; tip: "Mark Out  (O)"; enabled: mpv.loaded; onClicked: bar.setOut() }
        IconButton { text: "+ Marker"; tip: "Add marker at playhead  (M)"; enabled: mpv.loaded; onClicked: bar.addMarker() }

        Item { Layout.fillWidth: true }

        IconButton { text: "Mute"; checked: mpv.muted; tip: "Mute"; onClicked: mpv.muted = !mpv.muted }
        Slider {
            id: vol
            Layout.preferredWidth: 96
            from: 0; to: 130; value: mpv.volume
            focusPolicy: Qt.NoFocus
            onMoved: mpv.volume = value
            ToolTip.visible: hovered || pressed
            ToolTip.text: Math.round(value) + "%"
        }
        IconButton { text: bar.panelsVisible ? "Hide panels" : "Show panels"; tip: "Side panels  (H)"; onClicked: bar.togglePanels() }
        IconButton { text: "Full screen"; tip: "Full screen  (F, Esc to leave)"; onClicked: bar.toggleFullscreen() }
    }
}
