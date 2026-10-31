import QtQuick
import QtQuick.Controls
import Slate

Switch {
    id: s
    focusPolicy: Qt.NoFocus
    indicator: Rectangle {
        implicitWidth: 34; implicitHeight: 20; radius: 10
        x: s.width - width; anchors.verticalCenter: parent.verticalCenter
        color: s.checked ? Theme.accent : Theme.press
        Behavior on color { ColorAnimation { duration: 120 } }
        Rectangle {
            width: 14; height: 14; radius: 7; y: 3
            x: s.checked ? parent.width - width - 3 : 3
            color: "white"
            Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }
    }
    contentItem: Text {
        text: s.text; color: Theme.ink; font.pixelSize: Theme.fontBody
        rightPadding: s.indicator.width + 12
        verticalAlignment: Text.AlignVCenter; wrapMode: Text.WordWrap
    }
}
