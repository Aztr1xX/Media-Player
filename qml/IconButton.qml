import QtQuick
import Take
import QtQuick.Controls

// Flat button that never takes keyboard focus, so Space always means play/pause.
AbstractButton {
    id: b
    property string tip: ""
    property bool primary: false
    property int fontSize: 13
    focusPolicy: Qt.NoFocus
    hoverEnabled: true
    implicitHeight: 30
    implicitWidth: Math.max(34, label.implicitWidth + 20)
    opacity: enabled ? 1 : 0.4

    background: Rectangle {
        radius: Theme.radius
        color: b.primary ? (b.down ? Qt.darker(Theme.accent, 1.2) : Theme.accent)
                         : (b.checked ? Qt.rgba(1, 0.6, 0.24, 0.16) : (b.down ? Theme.line : Theme.raise))
        border.color: b.checked ? Theme.accent : (b.hovered && !b.primary ? Theme.muted : (b.primary ? Theme.accent : Theme.line))
        border.width: 1
    }
    contentItem: Text {
        id: label
        text: b.text
        color: b.primary ? Theme.accentInk : Theme.ink
        font.pixelSize: b.fontSize
        font.weight: b.primary ? Font.DemiBold : Font.Normal
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    ToolTip.visible: hovered && tip.length > 0
    ToolTip.delay: 500
    ToolTip.text: tip
}
