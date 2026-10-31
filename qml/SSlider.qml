import QtQuick
import QtQuick.Controls
import Slate

Slider {
    id: s
    focusPolicy: Qt.NoFocus
    implicitHeight: 24
    property string valueText: ""          // shown in a bubble above the handle while hovered or dragged
    background: Rectangle {
        x: s.leftPadding; y: s.topPadding + s.availableHeight / 2 - height / 2
        width: s.availableWidth; height: 4; radius: 2
        color: Theme.press
        Rectangle { width: s.visualPosition * parent.width; height: parent.height; radius: 2; color: s.hovered || s.pressed ? Theme.accent : Theme.ink2 }
    }
    handle: Rectangle {
        x: s.leftPadding + s.visualPosition * (s.availableWidth - width)
        y: s.topPadding + s.availableHeight / 2 - height / 2
        width: 12; height: 12; radius: 6
        color: "white"
        visible: s.hovered || s.pressed

        Rectangle {
            visible: s.valueText !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.top; anchors.bottomMargin: 8
            width: Math.max(36, vt.implicitWidth + 14); height: 22; radius: 6
            color: "#23262b"; border.color: Theme.lineStrong
            Text { id: vt; anchors.centerIn: parent; text: s.valueText; color: Theme.ink; font.pixelSize: 11; font.family: Theme.mono }
        }
    }
}
