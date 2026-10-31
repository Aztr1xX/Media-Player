import QtQuick
import QtQuick.Controls
import Slate

// Ctrl+K: find and run any action by typing part of its name.
Popup {
    id: pal
    property var actions: []      // [{ name, keys, run, category }]
    property var shown: []
    property int sel: 0

    modal: true
    focus: true
    dim: true
    x: Math.round((parent.width - width) / 2)
    y: Math.round(parent.height * 0.12)
    width: Math.min(600, parent.width - 40)
    height: 62 + Math.max(40, Math.min(10, pal.shown.length) * 36) + 8
    padding: 0
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.45) }

    function refilter() {
        const words = input.text.toLowerCase().trim().split(/\s+/).filter(w => w.length)
        shown = actions.filter(a => words.every(w => (a.name + " " + (a.category || "")).toLowerCase().indexOf(w) >= 0))
        sel = 0
    }
    function runSelected() {
        const a = shown[sel]
        close()
        if (a) Qt.callLater(a.run)
    }
    onOpened: { input.text = ""; refilter(); input.forceActiveFocus() }

    background: Rectangle { color: "#1b1d21"; border.color: Theme.lineStrong; radius: Theme.radiusLg }

    Icon { x: 16; y: 16; name: "search"; size: 18; color: Theme.ink3 }
    TextField {
        id: input
        x: 40; y: 0; width: parent.width - 40; height: 50
        leftPadding: 6
        placeholderText: "Search actions"
        placeholderTextColor: Theme.ink3
        color: Theme.ink
        font.pixelSize: Theme.fontTitle
        selectByMouse: true
        selectionColor: Theme.accent
        background: Item {}
        onTextChanged: pal.refilter()
        Keys.onDownPressed: pal.sel = Math.min(pal.shown.length - 1, pal.sel + 1)
        Keys.onUpPressed: pal.sel = Math.max(0, pal.sel - 1)
        Keys.onReturnPressed: pal.runSelected()
        Keys.onEnterPressed: pal.runSelected()
    }
    Rectangle { y: 50; width: parent.width; height: 1; color: Theme.line }

    ListView {
        id: list
        x: 6; y: 56
        width: parent.width - 12
        height: parent.height - 62
        clip: true
        model: pal.shown
        currentIndex: pal.sel
        boundsBehavior: Flickable.StopAtBounds
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
        delegate: Rectangle {
            required property var modelData
            required property int index
            width: list.width; height: 36; radius: Theme.radius
            color: index === pal.sel ? Theme.hover : "transparent"
            Text { x: 12; anchors.verticalCenter: parent.verticalCenter; text: modelData.name; color: Theme.ink; font.pixelSize: Theme.fontBody }
            Row {
                anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Text { text: modelData.category || ""; color: Theme.ink3; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                Rectangle {
                    visible: modelData.keys.length > 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: k.implicitWidth + 12; height: 20; radius: 4
                    color: Theme.bg; border.color: Theme.lineStrong
                    Text { id: k; anchors.centerIn: parent; text: modelData.keys; color: Theme.ink2; font.pixelSize: 11 }
                }
            }
            MouseArea { anchors.fill: parent; hoverEnabled: true; onPositionChanged: pal.sel = index; onClicked: { pal.sel = index; pal.runSelected() } }
        }
        Text { visible: pal.shown.length === 0; x: 12; y: 10; text: "No matching action"; color: Theme.ink3; font.pixelSize: Theme.fontBody }
    }
}
