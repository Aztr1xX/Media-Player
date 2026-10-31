import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Slate

// Paste a link (YouTube and most video sites work through yt-dlp).
Popup {
    id: dlg
    signal accepted(string url)
    modal: true
    focus: true
    anchors.centerIn: Overlay.overlay
    width: Math.min(560, parent.width - 60)
    padding: 22
    Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.5) }
    background: Rectangle { color: Theme.panel; radius: Theme.radiusLg; border.color: Theme.lineStrong }
    onOpened: { field.text = ""; field.forceActiveFocus() }
    function go() { const u = field.text.trim(); if (!u) return; close(); accepted(u) }

    ColumnLayout {
        width: parent.width
        spacing: 12
        Text { text: "Open URL"; color: Theme.ink; font.pixelSize: Theme.fontTitle; font.weight: Font.DemiBold }
        TextField {
            id: field
            Layout.fillWidth: true
            implicitHeight: 36
            placeholderText: "https://"
            placeholderTextColor: Theme.ink3
            color: Theme.ink; font.pixelSize: Theme.fontBody
            selectByMouse: true; selectionColor: Theme.accent
            background: Rectangle { radius: Theme.radius; color: Theme.bg; border.color: field.activeFocus ? Theme.accent : Theme.line }
            onAccepted: dlg.go()
            Keys.onEscapePressed: dlg.close()
        }
        Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: "Works with direct video links and sites like YouTube."; color: Theme.ink3; font.pixelSize: 12 }
        Row {
            Layout.alignment: Qt.AlignRight
            spacing: 8
            Btn { flat: false; text: "Cancel"; onClicked: dlg.close() }
            Btn { primary: true; text: "Open"; enabled: field.text.trim().length > 0; onClicked: dlg.go() }
        }
    }
}
