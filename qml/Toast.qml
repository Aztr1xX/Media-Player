import QtQuick
import Slate

// Short status message near the bottom of the picture, with an optional "Show in folder".
Rectangle {
    id: t
    property string revealPath: ""
    function show(msg, path) {
        label.text = msg
        revealPath = path || ""
        opacity = 1
        hideTimer.restart()
    }
    width: row.implicitWidth + 28
    height: 36
    radius: 18
    color: "#ee1f2226"
    border.color: Theme.lineStrong
    opacity: 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 160 } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 14
        Text { id: label; color: Theme.ink; font.pixelSize: Theme.fontBody; anchors.verticalCenter: parent.verticalCenter }
        Text {
            visible: t.revealPath.length > 0
            text: App.isWindows ? "Show in Explorer" : "Show in folder"
            color: revealMouse.containsMouse ? Theme.accentHover : Theme.accent
            font.pixelSize: Theme.fontBody; font.weight: Font.DemiBold
            anchors.verticalCenter: parent.verticalCenter
            MouseArea { id: revealMouse; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: App.revealInFolder(t.revealPath) }
        }
    }
    HoverHandler { onHoveredChanged: hovered ? hideTimer.stop() : hideTimer.restart() }
    Timer { id: hideTimer; interval: 3000; onTriggered: t.opacity = 0 }
}
