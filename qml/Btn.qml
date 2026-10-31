import QtQuick
import QtQuick.Controls
import Slate

// Toolbar button: icon, text, or both. "primary" fills it with the accent colour.
AbstractButton {
    id: b
    property string glyph: ""
    property string tip: ""
    property string keys: ""
    property bool primary: false
    property bool flat: true
    property bool active: checked
    property int iconSize: 18
    property color iconColor: primary ? Theme.accentInk : (active ? Theme.accent : (b.enabled ? Theme.ink : Theme.ink3))
    focusPolicy: Qt.NoFocus
    hoverEnabled: true
    implicitHeight: 32
    implicitWidth: text.length ? row.implicitWidth + (icon ? 20 : 24) : 32
    opacity: enabled ? 1 : 0.45

    contentItem: Item {
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 7
            Icon { visible: b.glyph !== ""; name: b.glyph; size: b.iconSize; color: b.iconColor; anchors.verticalCenter: parent.verticalCenter }
            Text {
                visible: b.text.length > 0
                text: b.text
                color: b.primary ? Theme.accentInk : (b.active ? Theme.accent : Theme.ink)
                font.pixelSize: Theme.fontBody
                font.weight: b.primary ? Font.DemiBold : Font.Normal
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
    background: Rectangle {
        radius: Theme.radius
        color: b.primary ? (b.down ? Qt.darker(Theme.accent, 1.15) : (b.hovered ? Theme.accentHover : Theme.accent))
                         : (b.down ? Theme.press : (b.hovered ? Theme.hover : (b.flat ? "transparent" : Theme.raise)))
        border.color: b.flat || b.primary ? "transparent" : Theme.line
        Behavior on color { ColorAnimation { duration: 90 } }
    }
    Tip { visible: b.hovered && b.tip.length > 0; text: b.tip; keys: b.keys }
}
