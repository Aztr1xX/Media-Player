import QtQuick
import Slate

// A row of mutually exclusive options: [{ text, icon }].
Rectangle {
    id: seg
    property var options: []
    property int current: 0
    signal picked(int index)
    implicitHeight: 30
    implicitWidth: row.implicitWidth + 6
    radius: Theme.radius
    color: Theme.bg
    border.color: Theme.line
    Row {
        id: row
        anchors.fill: parent; anchors.margins: 3
        spacing: 2
        Repeater {
            model: seg.options
            delegate: Rectangle {
                required property var modelData
                required property int index
                width: (row.width - (seg.options.length - 1) * 2) / seg.options.length
                height: row.height; radius: 4
                color: index === seg.current ? Theme.hover : (ma.containsMouse ? Theme.raise : "transparent")
                Row {
                    anchors.centerIn: parent; spacing: 6
                    Icon { visible: !!modelData.icon; name: modelData.icon || ""; size: 15; color: index === seg.current ? Theme.ink : Theme.ink2; anchors.verticalCenter: parent.verticalCenter }
                    Text { visible: !!modelData.text; text: modelData.text || ""; color: index === seg.current ? Theme.ink : Theme.ink2; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: { seg.current = index; seg.picked(index) } }
            }
        }
    }
}
