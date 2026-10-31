import QtQuick
import Take
import QtQuick.Controls


// Ctrl+K: find and run any action by typing part of its name.
Popup {
    id: pal
    property var actions: []      // [{ name, keys, run, enabled? }]
    property var shown: []
    property int sel: 0

    modal: true
    focus: true
    dim: true
    x: (parent.width - width) / 2
    y: Math.round(parent.height * 0.14)
    width: Math.min(560, parent.width - 40)
    height: Math.min(420, 54 + list.contentHeight + 12)
    padding: 0
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    function refilter() {
        const words = input.text.toLowerCase().trim().split(/\s+/).filter(w => w.length)
        shown = actions.filter(a => (a.enabled === undefined || a.enabled()) && words.every(w => a.name.toLowerCase().indexOf(w) >= 0))
        sel = 0
    }
    function runSelected() {
        const a = shown[sel]
        close()
        if (a) Qt.callLater(a.run)
    }
    onOpened: { input.text = ""; refilter(); input.forceActiveFocus() }

    background: Rectangle { color: Theme.panel; border.color: Theme.line; radius: 10 }

    TextField {
        id: input
        x: 0; y: 0; width: parent.width; height: 48
        leftPadding: 14
        placeholderText: "Type an action: export, speed, loop, marker…"
        placeholderTextColor: Theme.muted
        color: Theme.ink
        font.pixelSize: 15
        background: Rectangle { color: "transparent"; Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.line } }
        onTextChanged: pal.refilter()
        Keys.onDownPressed: pal.sel = Math.min(pal.shown.length - 1, pal.sel + 1)
        Keys.onUpPressed: pal.sel = Math.max(0, pal.sel - 1)
        Keys.onReturnPressed: pal.runSelected()
        Keys.onEnterPressed: pal.runSelected()
    }

    ListView {
        id: list
        x: 6; y: 54
        width: parent.width - 12
        height: parent.height - 60
        clip: true
        model: pal.shown
        currentIndex: pal.sel
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
        delegate: Rectangle {
            required property var modelData
            required property int index
            width: list.width; height: 34; radius: 6
            color: index === pal.sel ? Theme.raise : "transparent"
            Text { x: 10; anchors.verticalCenter: parent.verticalCenter; text: modelData.name; color: Theme.ink; font.pixelSize: 13 }
            Rectangle {
                visible: modelData.keys.length > 0
                anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                width: k.implicitWidth + 10; height: 20; radius: 4
                color: Theme.bg; border.color: Theme.line
                Text { id: k; anchors.centerIn: parent; text: modelData.keys; color: Theme.muted; font.pixelSize: 11; font.family: Theme.mono }
            }
            MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: pal.sel = index; onClicked: { pal.sel = index; pal.runSelected() } }
        }
        Text {
            visible: pal.shown.length === 0
            x: 10; y: 8
            text: "No matching action"
            color: Theme.muted; font.pixelSize: 13
        }
    }
}
