import QtQuick
import Slate

// Vertical / square crop guide over the picture: shows what a Shorts, Instagram or square
// version of the shot would keep. Drag the frame sideways to try a different crop;
// double-click to centre it again.
Item {
    id: g
    property int mode: 0                      // 0 off, 1 = 9:16, 2 = 4:5, 3 = 1:1
    property real videoWidth: 0
    property real videoHeight: 0
    readonly property var aspects: [0, 9 / 16, 4 / 5, 1]
    readonly property var names: ["", "9:16", "4:5", "1:1"]
    property real offset: 0                   // -1 … 1 across the free space
    onModeChanged: offset = 0

    // where the picture is drawn inside this item (letterboxed)
    readonly property real va: videoHeight > 0 ? videoWidth / videoHeight : 16 / 9
    readonly property real pw: width / height > va ? height * va : width
    readonly property real ph: width / height > va ? height : width / va
    readonly property real px: (width - pw) / 2
    readonly property real py: (height - ph) / 2
    // the crop frame
    readonly property real a: aspects[mode] || 1
    readonly property real cw: a < va ? ph * a : pw
    readonly property real ch: a < va ? ph : pw / a
    readonly property real cx: px + (pw - cw) / 2 + offset * (pw - cw) / 2
    readonly property real cy: py + (ph - ch) / 2

    readonly property color shade: Qt.rgba(0, 0, 0, 0.6)
    Rectangle { x: g.px; y: g.py; width: g.cx - g.px; height: g.ph; color: g.shade }
    Rectangle { x: g.cx + g.cw; y: g.py; width: g.px + g.pw - g.cx - g.cw; height: g.ph; color: g.shade }
    Rectangle { x: g.cx; y: g.py; width: g.cw; height: g.cy - g.py; color: g.shade }
    Rectangle { x: g.cx; y: g.cy + g.ch; width: g.cw; height: g.py + g.ph - g.cy - g.ch; color: g.shade }

    Rectangle {
        id: frame
        x: g.cx; y: g.cy; width: g.cw; height: g.ch
        color: "transparent"
        border.color: Qt.rgba(1, 1, 1, 0.85); border.width: 1
        // rule of thirds
        Repeater {
            model: 2
            delegate: Rectangle { required property int index; x: frame.width * (index + 1) / 3; width: 1; height: frame.height; color: Qt.rgba(1, 1, 1, 0.18) }
        }
        Repeater {
            model: 2
            delegate: Rectangle { required property int index; y: frame.height * (index + 1) / 3; height: 1; width: frame.width; color: Qt.rgba(1, 1, 1, 0.18) }
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 10
            width: lbl.implicitWidth + 16; height: 22; radius: 11
            color: Qt.rgba(0, 0, 0, 0.65)
            Text { id: lbl; anchors.centerIn: parent; text: g.names[g.mode]; color: "white"; font.pixelSize: 11 }
        }
        MouseArea {
            anchors.fill: parent
            enabled: g.pw - g.cw > 1
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            property real startX: 0
            property real startOffset: 0
            onPressed: (m) => { startX = m.x + frame.x; startOffset = g.offset }
            onPositionChanged: (m) => {
                const free = (g.pw - g.cw) / 2
                if (free > 0) g.offset = Math.max(-1, Math.min(1, startOffset + (m.x + frame.x - startX) / free))
            }
            onDoubleClicked: g.offset = 0
        }
    }
}
