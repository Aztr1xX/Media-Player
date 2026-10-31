import QtQuick
import Slate
import QtQuick.Controls


// Short status message at the bottom of the video. Optional "Show in folder" link.
Rectangle {
    id: t
    property string revealPath: ""
    function show(msg, path) {
        label.text = msg
        revealPath = path || ""
        opacity = 1
        hideTimer.restart()
    }
    width: Math.min(parent ? parent.width - 40 : 600, row.implicitWidth + 28)
    height: 36
    radius: 8
    color: Qt.rgba(0.06, 0.07, 0.08, 0.94)
    border.color: Theme.line
    opacity: 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 180 } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 12
        Text { id: label; color: Theme.ink; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
        Text {
            visible: t.revealPath.length > 0
            text: "Show in folder"
            color: Theme.accent
            font.pixelSize: 13
            font.underline: revealMouse.containsMouse
            anchors.verticalCenter: parent.verticalCenter
            MouseArea { id: revealMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: App.revealInFolder(t.revealPath) }
        }
    }
    HoverHandler { onHoveredChanged: hovered ? hideTimer.stop() : hideTimer.restart() }
    Timer { id: hideTimer; interval: 3200; onTriggered: t.opacity = 0 }
}
