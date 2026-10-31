import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Slate

// Timecode, playback controls, review tools and output controls under the timeline.
Item {
    id: bar
    required property var mpv
    required property var win
    property bool overlay: false
    implicitHeight: 52

    function fmt(t) { return mpv.hasVideo && mpv.fps > 0 ? App.formatTimecode(t, mpv.fps) : App.formatClock(t) }
    readonly property bool compact: width < 900

    Rectangle { anchors.fill: parent; color: bar.overlay ? "transparent" : Theme.chrome }

    // left: timecode
    Column {
        id: tc
        anchors.left: parent.left; anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1
        Text {
            text: bar.mpv.loaded ? bar.fmt(bar.mpv.position) : (bar.mpv.hasVideo ? "00:00:00:00" : "0:00")
            color: bar.mpv.loaded ? Theme.ink : Theme.ink3
            font.pixelSize: 17; font.family: Theme.mono
        }
        Text {
            text: !bar.mpv.loaded ? " " : (bar.mpv.hasVideo && bar.mpv.fps > 0
                  ? "Frame " + bar.mpv.frame + "  ·  " + App.formatClock(bar.mpv.duration)
                  : "of " + App.formatClock(bar.mpv.duration))
            color: Theme.ink3; font.pixelSize: 11; font.family: Theme.mono
        }
    }

    // centre: transport
    Row {
        id: centre
        anchors.centerIn: parent
        spacing: 4

        Row {
            spacing: 2
            visible: !bar.compact
            anchors.verticalCenter: parent.verticalCenter
            Btn { glyph: "in"; tip: "Set In point"; keys: "I"; enabled: bar.mpv.loaded; active: App.inPoint >= 0; onClicked: bar.win.setIn() }
            Btn { glyph: "out"; tip: "Set Out point"; keys: "O"; enabled: bar.mpv.loaded; active: App.outPoint >= 0; onClicked: bar.win.setOut() }
            Btn { glyph: "marker"; tip: "Add marker"; keys: "M"; enabled: bar.mpv.loaded; onClicked: bar.win.addMarker() }
        }
        Item { width: bar.compact ? 0 : 14; height: 1 }
        Btn { glyph: "frame-back"; tip: "Previous frame"; keys: ","; enabled: bar.mpv.loaded; anchors.verticalCenter: parent.verticalCenter; onClicked: bar.mpv.stepFrame(-1) }
        AbstractButton {
            id: play
            anchors.verticalCenter: parent.verticalCenter
            width: 40; height: 40
            focusPolicy: Qt.NoFocus
            hoverEnabled: true
            enabled: bar.mpv.loaded
            onClicked: { bar.win.rewindRate = 0; bar.mpv.togglePause() }
            background: Rectangle {
                radius: 20
                color: play.down ? "#d9dce1" : (play.hovered ? "#ffffff" : Theme.ink)
                opacity: play.enabled ? 1 : 0.35
            }
            contentItem: Item {
                Icon {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: bar.mpv.paused || !bar.mpv.loaded ? 1 : 0
                    name: bar.mpv.paused || !bar.mpv.loaded ? "play" : "pause"
                    size: 20; color: "#0e0f11"
                }
            }
            Tip { visible: play.hovered; text: bar.mpv.paused ? "Play" : "Pause"; keys: "Space" }
        }
        Btn { glyph: "frame-fwd"; tip: "Next frame"; keys: "."; enabled: bar.mpv.loaded; anchors.verticalCenter: parent.verticalCenter; onClicked: bar.mpv.stepFrame(1) }
        Item { width: 14; height: 1 }
        Btn {
            anchors.verticalCenter: parent.verticalCenter
            glyph: "loop"; tip: "Loop In to Out"; keys: "Ctrl+L"
            enabled: bar.mpv.loaded
            active: bar.mpv.loopA >= 0
            onClicked: bar.win.toggleLoop()
        }
        Btn {
            anchors.verticalCenter: parent.verticalCenter
            visible: !bar.compact
            glyph: "skip-silence"; tip: bar.win.skipSilence ? "Skipping silences (on)" : "Skip silences"; keys: "Ctrl+Shift+K"
            enabled: bar.mpv.loaded
            active: bar.win.skipSilence
            onClicked: bar.win.toggleSkipSilence()
        }
    }

    // right: output
    Row {
        anchors.right: parent.right; anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Btn {
            id: speedBtn
            text: (Math.round(bar.mpv.speed * 100) / 100) + "×"
            tip: "Playback speed"; keys: "[ ]"
            implicitWidth: 52
            active: Math.abs(bar.mpv.speed - 1) > 0.001
            onClicked: speedMenu.popup(speedBtn, 0, -speedMenu.implicitHeight - 4)
            SMenu {
                id: speedMenu
                implicitWidth: 150
                Repeater {
                    model: bar.win.speeds
                    delegate: SMenuItem {
                        required property double modelData
                        text: modelData + "×"
                        checkable: true
                        checked: Math.abs(bar.mpv.speed - modelData) < 0.001
                        onTriggered: bar.mpv.speed = modelData
                    }
                }
            }
        }
        Btn {
            id: tracksBtn
            glyph: "subtitles"; tip: "Audio and subtitles"
            enabled: bar.mpv.loaded
            active: bar.mpv.subtitleTrack > 0
            onClicked: tracksMenu.popup(tracksBtn, 0, -tracksMenu.implicitHeight - 4)
            SMenu {
                id: tracksMenu
                implicitWidth: 300
                MenuSeparator { contentItem: Text { text: "AUDIO"; color: Theme.ink3; font.pixelSize: 10; font.letterSpacing: 0.8; leftPadding: 10; topPadding: 4 } }
                Repeater {
                    model: bar.mpv.audioTracks
                    delegate: SMenuItem {
                        required property var modelData
                        text: modelData.label || ("Track " + modelData.id)
                        checkable: true; checked: bar.mpv.audioTrack === modelData.id
                        onTriggered: bar.mpv.setAudioTrack(modelData.id)
                    }
                }
                MenuSeparator { contentItem: Text { text: "SUBTITLES"; color: Theme.ink3; font.pixelSize: 10; font.letterSpacing: 0.8; leftPadding: 10; topPadding: 6 } }
                SMenuItem { text: "Off"; checkable: true; checked: bar.mpv.subtitleTrack === 0; onTriggered: bar.mpv.setSubtitleTrack(0) }
                Repeater {
                    model: bar.mpv.subtitleTracks
                    delegate: SMenuItem {
                        required property var modelData
                        text: modelData.label || ("Subtitle " + modelData.id)
                        checkable: true; checked: bar.mpv.subtitleTrack === modelData.id
                        onTriggered: bar.mpv.setSubtitleTrack(modelData.id)
                    }
                }
                SMenuItem { text: "Load subtitle file…"; glyph: "file"; onTriggered: bar.win.openSubtitleDialog() }
            }
        }
        Btn {
            glyph: bar.mpv.muted || bar.mpv.volume === 0 ? "mute" : (bar.mpv.volume < 50 ? "volume-low" : "volume")
            tip: bar.mpv.muted ? "Unmute" : "Mute"; keys: "Ctrl+M"
            onClicked: bar.mpv.muted = !bar.mpv.muted
        }
        SSlider {
            width: bar.compact ? 64 : 92
            anchors.verticalCenter: parent.verticalCenter
            from: 0; to: 100
            value: bar.mpv.volume
            onMoved: { bar.mpv.volume = value; if (bar.mpv.muted) bar.mpv.muted = false }
        }
        Item { width: 6; height: 1 }
        Btn {
            glyph: bar.win.isFull ? "fullscreen-exit" : "fullscreen"
            tip: bar.win.isFull ? "Exit full screen" : "Full screen"; keys: "F"
            onClicked: bar.win.toggleFullscreen()
        }
    }
}
