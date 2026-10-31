import QtQuick
import QtQuick.Controls
import Slate

// Timeline: time ruler, audio waveform, In/Out range, markers and playhead.
// Click or drag to scrub (fast while dragging, exact on release).
// Ctrl+wheel zooms around the pointer, wheel scrolls when zoomed; hover shows a frame preview.
Item {
    id: tl
    required property var mpv
    property bool overlay: false            // drawn over the video in full screen
    implicitHeight: 78

    readonly property double dur: mpv.duration > 0 ? mpv.duration : 0
    property double viewStart: 0
    property double viewSpan: dur           // seconds visible
    readonly property double viewEnd: viewStart + viewSpan
    readonly property bool zoomed: dur > 0 && viewSpan < dur - 0.001
    onDurChanged: { viewStart = 0; viewSpan = dur }

    function xFor(t) { return viewSpan > 0 ? (t - viewStart) / viewSpan * track.width : 0 }
    function tFor(x) { return viewSpan > 0 ? Math.max(0, Math.min(dur, viewStart + x / track.width * viewSpan)) : 0 }
    function fmt(t) { return mpv.hasVideo && mpv.fps > 0 ? App.formatTimecode(t, mpv.fps) : App.formatClock(t) }
    function clampView() {
        viewSpan = Math.max(Math.min(dur, viewSpan), Math.min(dur, 2))
        viewStart = Math.max(0, Math.min(dur - viewSpan, viewStart))
    }
    function zoomAt(factor, x) {
        if (dur <= 0) return
        const t = tFor(x)
        viewSpan = viewSpan * factor
        clampView()
        viewStart = t - x / track.width * viewSpan
        clampView()
    }
    function zoomBy(factor) { zoomAt(factor, Math.max(0, Math.min(track.width, xFor(mpv.position)))) }
    function resetZoom() { viewStart = 0; viewSpan = dur }

    // Keep the playhead in view while playing when zoomed in.
    Connections {
        target: tl.mpv
        function onPositionChanged() {
            if (!tl.zoomed || area.pressed) return
            const p = tl.mpv.position
            if (p < tl.viewStart || p > tl.viewEnd) { tl.viewStart = p - tl.viewSpan * 0.1; tl.clampView() }
        }
    }

    Rectangle { anchors.fill: parent; color: tl.overlay ? "transparent" : Theme.chrome }

    // ---- ruler -------------------------------------------------------------------
    Item {
        id: ruler
        x: 12; y: 4
        width: parent.width - 24; height: 16
        readonly property var steps: [0.1, 0.2, 0.5, 1, 2, 5, 10, 15, 30, 60, 120, 300, 600, 900, 1800, 3600]
        readonly property double step: {
            if (tl.viewSpan <= 0 || width <= 0) return 1
            for (let i = 0; i < steps.length; ++i) if (steps[i] / tl.viewSpan * width >= 84) return steps[i]
            return 7200
        }
        readonly property var ticks: {
            const out = []
            if (tl.viewSpan <= 0) return out
            const first = Math.ceil(tl.viewStart / step - 1e-9) * step
            for (let t = first; t <= tl.viewEnd + 1e-6 && out.length < 60; t += step) out.push(t)
            return out
        }
        Repeater {
            model: ruler.ticks
            delegate: Item {
                required property double modelData
                x: tl.xFor(modelData)
                Rectangle { width: 1; height: 5; y: 11; color: Theme.lineStrong }
                Text {
                    x: 4; y: 0
                    visible: parent.x + 4 + implicitWidth < ruler.width
                    text: ruler.step < 1 ? App.formatClock(modelData) + "." + Math.round((modelData % 1) * 10) % 10 : App.formatClock(modelData)
                    color: Theme.ink3; font.pixelSize: 10; font.family: Theme.mono
                }
            }
        }
    }

    // ---- track -------------------------------------------------------------------
    Rectangle {
        id: track
        x: 12; y: 22
        width: parent.width - 24; height: 44
        radius: 4
        color: tl.overlay ? Qt.rgba(0, 0, 0, 0.45) : Theme.bg
        border.color: Theme.line
        clip: true

        WaveformItem {
            anchors.fill: parent; anchors.topMargin: 3; anchors.bottomMargin: 3
            viewStart: tl.viewStart; viewEnd: tl.viewEnd
            color: "#7d8693"; peakColor: "#3b4048"
            visible: hasData
        }
        Text {
            anchors.centerIn: parent
            visible: tl.dur > 0 && !Media.waveformReady && Media.file !== "" && Media.peakRevision >= 0 && Media.waveformProgress < 0.02
            text: "Reading audio…"
            color: Theme.ink3; font.pixelSize: 11
        }
        // played part
        Rectangle {
            width: Math.max(0, Math.min(track.width, tl.xFor(tl.mpv.position)))
            height: parent.height
            color: Qt.rgba(0.31, 0.55, 1, 0.10)
        }
        // in/out range
        Rectangle {
            visible: App.inPoint >= 0 || App.outPoint >= 0
            readonly property double a: App.inPoint >= 0 ? App.inPoint : 0
            readonly property double b: App.outPoint >= 0 ? App.outPoint : tl.dur
            x: tl.xFor(a)
            width: Math.max(2, tl.xFor(b) - tl.xFor(a))
            height: parent.height
            color: Qt.rgba(0.31, 0.55, 1, 0.14)
            Rectangle { visible: App.inPoint >= 0; width: 2; height: parent.height; color: Theme.accent }
            Rectangle { visible: App.outPoint >= 0; x: parent.width - 2; width: 2; height: parent.height; color: Theme.accent }
        }
        // markers
        Repeater {
            model: App.markers
            delegate: Item {
                id: mk
                required property double time
                required property int kind
                x: tl.xFor(time) - 5
                width: 10; height: track.height
                visible: x > -10 && x < track.width + 10
                Rectangle { x: 4; width: 2; height: parent.height; color: Theme.kindColor(mk.kind); opacity: 0.8 }
                Rectangle { x: 1; y: 0; width: 8; height: 8; radius: 2; color: Theme.kindColor(mk.kind) }
            }
        }
        // playhead
        Rectangle {
            x: tl.xFor(tl.mpv.position) - 1
            width: 2; height: parent.height
            color: Theme.ink
            visible: tl.dur > 0 && x >= -2 && x <= track.width
        }
    }

    // playhead knob on the ruler
    Rectangle {
        readonly property double px: track.x + tl.xFor(tl.mpv.position)
        visible: tl.dur > 0 && px >= track.x - 1 && px <= track.x + track.width + 1
        x: px - 5; y: track.y - 7
        width: 10; height: 7; radius: 2
        color: Theme.ink
    }

    // zoom scrollbar
    Rectangle {
        visible: tl.zoomed
        x: track.x; y: track.y + track.height + 4
        width: track.width; height: 3; radius: 1.5
        color: Theme.raise
        Rectangle {
            x: tl.dur > 0 ? tl.viewStart / tl.dur * parent.width : 0
            width: tl.dur > 0 ? Math.max(12, tl.viewSpan / tl.dur * parent.width) : 0
            height: parent.height; radius: 1.5
            color: Theme.ink3
        }
    }

    // ---- hover preview ----------------------------------------------------------------
    Rectangle {
        id: preview
        readonly property double t: tl.tFor(area.mouseX)
        readonly property bool hasThumb: Media.spriteUrl !== "" && tl.mpv.hasVideo && Media.spriteCount > 0
        visible: area.containsMouse && tl.dur > 0 && !area.pressed
        width: hasThumb ? 178 : timeLabel.implicitWidth + 16
        height: hasThumb ? 100 + 24 : 24
        x: Math.max(4, Math.min(tl.width - width - 4, track.x + area.mouseX - width / 2))
        y: track.y - height - 10
        radius: 6
        color: "#f01b1d21"
        border.color: Theme.lineStrong
        z: 10
        Image {
            visible: preview.hasThumb
            x: 1; y: 1; width: 176; height: 99
            source: preview.hasThumb ? Media.spriteUrl : ""
            readonly property int idx: Math.max(0, Math.min(Media.spriteCount - 1, Math.floor(preview.t / Math.max(0.001, Media.spriteInterval))))
            sourceClipRect: Qt.rect((idx % 10) * 192, Math.floor(idx / 10) * 108, 192, 108)
            fillMode: Image.PreserveAspectFit
            cache: true
        }
        Text {
            id: timeLabel
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 4
            text: tl.fmt(preview.t)
            color: Theme.ink; font.pixelSize: 11; font.family: Theme.mono
        }
    }

    MouseArea {
        id: area
        x: track.x; y: ruler.y
        width: track.width; height: track.y + track.height - ruler.y + 4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: tl.dur > 0
        property bool wasPaused: true
        onPressed: (m) => { wasPaused = tl.mpv.paused; tl.mpv.paused = true; tl.mpv.seekTo(tl.tFor(m.x), false) }
        onPositionChanged: (m) => { if (pressed) tl.mpv.seekTo(tl.tFor(m.x), false) }
        onReleased: (m) => { tl.mpv.seekTo(tl.tFor(m.x), true); if (!wasPaused) tl.mpv.paused = false }
        onDoubleClicked: if (tl.zoomed) tl.resetZoom()
        onWheel: (w) => {
            const d = w.angleDelta.y !== 0 ? w.angleDelta.y : w.angleDelta.x
            if (w.modifiers & Qt.ControlModifier) tl.zoomAt(d > 0 ? 0.8 : 1.25, w.x)
            else if (tl.zoomed) { tl.viewStart -= d / 120 * tl.viewSpan * 0.1; tl.clampView() }
            else { w.accepted = false; return }
            w.accepted = true
        }
    }
}
