import QtQuick
import QtQuick.Controls
import Slate

MenuItem {
    id: mi
    property string keys: ""
    property string glyph: ""
    implicitHeight: 30
    leftPadding: 10; rightPadding: 10
    contentItem: Row {
        spacing: 9
        Item {
            width: 16; height: 16
            anchors.verticalCenter: parent.verticalCenter
            Icon { anchors.centerIn: parent; visible: mi.checkable ? mi.checked : mi.glyph !== ""; name: mi.checkable ? "check" : mi.glyph; size: 16; color: mi.checkable ? Theme.accent : Theme.ink2 }
        }
        Text {
            width: mi.availableWidth - 25 - (mi.keys ? kt.implicitWidth + 12 : 0)
            text: mi.text; elide: Text.ElideRight
            color: mi.enabled ? Theme.ink : Theme.ink3
            font.pixelSize: Theme.fontBody
            anchors.verticalCenter: parent.verticalCenter
        }
        Text { id: kt; visible: mi.keys !== ""; text: mi.keys; color: Theme.ink3; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
    }
    arrow: Icon { visible: mi.subMenu; x: mi.width - width - 8; anchors.verticalCenter: parent.verticalCenter; name: "chevron-right"; size: 14; color: Theme.ink2 }
    indicator: Item {}
    background: Rectangle { radius: 5; color: mi.highlighted && mi.enabled ? Theme.hover : "transparent" }
}
