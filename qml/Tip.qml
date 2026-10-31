import QtQuick
import QtQuick.Controls
import Slate

// Tooltip with an optional shortcut badge.
ToolTip {
    id: tip
    property string keys: ""
    delay: 450
    timeout: 6000
    padding: 0
    contentItem: Row {
        spacing: 8
        leftPadding: 9; rightPadding: 9; topPadding: 5; bottomPadding: 5
        Text { text: tip.text; color: Theme.ink; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
        Rectangle {
            visible: tip.keys.length > 0
            anchors.verticalCenter: parent.verticalCenter
            width: kt.implicitWidth + 10; height: 18; radius: 4
            color: Theme.bg; border.color: Theme.lineStrong
            Text { id: kt; anchors.centerIn: parent; text: tip.keys; color: Theme.ink2; font.pixelSize: 11 }
        }
    }
    background: Rectangle { color: "#23262b"; radius: 6; border.color: Theme.lineStrong }
}
