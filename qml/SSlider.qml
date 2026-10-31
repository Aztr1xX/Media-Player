import QtQuick
import QtQuick.Controls
import Slate

Slider {
    id: s
    focusPolicy: Qt.NoFocus
    implicitHeight: 24
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
    }
}
