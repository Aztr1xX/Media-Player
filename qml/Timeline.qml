import QtQuick
import Slate
import QtQuick.Controls


// Scrub bar: played range, In/Out range, marker flags, playhead and a hover readout.
// Click or drag to scrub; seeking is fast while dragging and exact on release.
Rectangle {
    id: tl
    required property var mpv
    implicitHeight: 64
    color: Theme.panel

    readonly property double dur: mpv.duration > 0 ? mpv.duration : 0
    function xFor(t) { return dur > 0 ? track.x + Math.max(0, Math.min(1, t / dur)) * track.width : track.x }
    function tFor(x) { return dur > 0 ? Math.max(0, Math.min(1, (x - track.x) / track.width)) * dur : 0 }
    function fmt(t) { return mpv.hasVideo && mpv.fps > 0 ? App.formatTimecode(t, mpv.fps) : App.formatClock(t) }

    Text {
        x: 12; y: 6
        color: Theme.muted; font.pixelSize: 11
        text: App.inPoint >= 0 || App.outPoint >= 0
              ? "In " + (App.inPoint >= 0 ? fmt(App.inPoint) : "--") + "   Out " + (App.outPoint >= 0 ? fmt(App.outPoint) : "--")
                + (App.inPoint >= 0 && App.outPoint > App.inPoint ? "   " + (App.outPoint - App.inPoint).toFixed(2) + " s" : "") + "   (X clears)"
              : "Timeline · click or drag to scrub · I / O set In and Out · M adds a marker"
    }
    Text {
        anchors.right: parent.right; anchors.rightMargin: 12; y: 6
        color: Theme.muted; font.pixelSize: 11; font.family: Theme.mono
        text: App.formatClock(tl.dur)
    }

    Rectangle {
        id: track
        x: 12; y: 24
        width: parent.width - 24
        height: 28
        radius: 4
        color: "#0b0d10"
        border.color: Theme.line

        // played portion
        Rectangle {
            width: tl.dur > 0 ? Math.max(0, Math.min(1, mpv.position / tl.dur)) * parent.width : 0
            height: parent.height; radius: 4
            color: Qt.rgba(1, 1, 1, 0.06)
        }
        // in/out range
        Rectangle {
            visible: App.inPoint >= 0 || App.outPoint >= 0
            readonly property double a: App.inPoint >= 0 ? App.inPoint : 0
            readonly property double b: App.outPoint >= 0 ? App.outPoint : tl.dur
            x: tl.xFor(a) - track.x
            width: Math.max(2, tl.xFor(b) - tl.xFor(a))
            height: parent.height
            color: Qt.rgba(1, 0.6, 0.24, 0.16)
            border.color: Theme.accent
            border.width: 0
            Rectangle { visible: App.inPoint >= 0; width: 2; height: parent.height; color: Theme.accent }
            Rectangle { visible: App.outPoint >= 0; x: parent.width - 2; width: 2; height: parent.height; color: Theme.accent }
        }
        // markers
        Repeater {
            model: App.markers
            delegate: Rectangle {
                required property double time
                required property int kind
                x: tl.xFor(time) - track.x - 1
                width: 3; height: track.height
                color: Theme.kindColor(kind)
            }
        }
        // playhead
        Rectangle {
            x: tl.xFor(mpv.position) - track.x - 1
            y: -4
            width: 2; height: track.height + 8
            color: Theme.accent
            visible: tl.dur > 0
        }
    }

    // hover readout
    Rectangle {
        id: hoverTip
        visible: area.containsMouse && tl.dur > 0
        x: Math.max(4, Math.min(tl.width - width - 4, area.mouseX - width / 2))
        y: track.y - height - 4
        width: tipText.implicitWidth + 12; height: 20; radius: 4
        color: Theme.bg; border.color: Theme.line
        Text { id: tipText; anchors.centerIn: parent; color: Theme.ink; font.pixelSize: 11; font.family: Theme.mono; text: tl.fmt(tl.tFor(area.mouseX)) }
    }

    MouseArea {
        id: area
        anchors.fill: track
        anchors.margins: -6
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: tl.dur > 0
        property bool wasPaused: true
        onPressed: (m) => { wasPaused = mpv.paused; mpv.paused = true; mpv.seekTo(tl.tFor(m.x + area.x), false) }
        onPositionChanged: (m) => { if (pressed) mpv.seekTo(tl.tFor(m.x + area.x), false) }
        onReleased: (m) => { mpv.seekTo(tl.tFor(m.x + area.x), true); if (!wasPaused) mpv.paused = false }
    }
}
