import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Slate

// Markers for the current clip, plus every export.
Item {
    id: panel
    required property var mpv
    required property var win
    function fmt(t) { return mpv.hasVideo && mpv.fps > 0 ? App.formatTimecode(t, mpv.fps) : App.formatClock(t) }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 14; Layout.rightMargin: 8
            Layout.preferredHeight: 44
            Text { text: "Markers"; color: Theme.ink; font.pixelSize: Theme.fontTitle; font.weight: Font.DemiBold }
            Text { text: App.markers.count > 0 ? App.markers.count : ""; color: Theme.ink3; font.pixelSize: Theme.fontBody }
            Item { Layout.fillWidth: true }
            Btn { glyph: "plus"; tip: "Add marker at playhead"; keys: "M"; enabled: panel.mpv.loaded; onClicked: panel.win.addMarker() }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: App.markers
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            readonly property int playingRow: { App.markers.count; return App.markers.rowNear(panel.mpv.position, panel.mpv.fps > 0 ? 0.5 / panel.mpv.fps : 0.02) }

            delegate: Rectangle {
                id: row
                required property int index
                required property double time
                required property string note
                required property int kind
                width: list.width
                height: 52
                color: rowHover.hovered ? Theme.raise : (index === list.playingRow ? Theme.accentSoft : "transparent")
                HoverHandler { id: rowHover }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (m) => {
                        if (m.button === Qt.RightButton) { rowMenu.popup(); return }
                        panel.mpv.paused = true; panel.mpv.seekTo(row.time, true)
                    }
                    onDoubleClicked: (m) => { if (m.button === Qt.LeftButton) row.edit() }
                }
                function edit() { editor.text = row.note; editor.visible = true; editor.forceActiveFocus(); editor.selectAll() }

                // kind
                AbstractButton {
                    id: kindBtn
                    x: 12; anchors.verticalCenter: parent.verticalCenter
                    width: 20; height: 20
                    focusPolicy: Qt.NoFocus
                    hoverEnabled: true
                    onClicked: kindMenu.popup(kindBtn, 0, kindBtn.height + 2)
                    contentItem: Item { Rectangle { anchors.centerIn: parent; width: 10; height: 10; radius: 5; color: Theme.kindColor(row.kind); border.width: kindBtn.hovered ? 2 : 0; border.color: Qt.lighter(Theme.kindColor(row.kind), 1.3) } }
                    background: Item {}
                    Tip { visible: kindBtn.hovered; text: Theme.kindName(row.kind) + ". Click to change" }
                    SMenu {
                        id: kindMenu
                        implicitWidth: 170
                        Repeater {
                            model: 3
                            delegate: SMenuItem {
                                required property int index
                                text: Theme.kindName(index); checkable: true; checked: row.kind === index
                                onTriggered: App.markers.setKind(row.index, index)
                            }
                        }
                    }
                }
                Column {
                    x: 40; anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 40 - 40
                    spacing: 3
                    Text {
                        visible: !editor.visible
                        width: parent.width
                        text: row.note || "Untitled"
                        color: row.note ? Theme.ink : Theme.ink3
                        font.pixelSize: Theme.fontBody; elide: Text.ElideRight
                    }
                    TextField {
                        id: editor
                        visible: false
                        width: parent.width
                        height: 24
                        leftPadding: 6; rightPadding: 6; topPadding: 2; bottomPadding: 2
                        font.pixelSize: Theme.fontBody
                        color: Theme.ink
                        selectByMouse: true
                        selectionColor: Theme.accent
                        background: Rectangle { color: Theme.bg; border.color: Theme.accent; radius: 4 }
                        onAccepted: { App.markers.setNote(row.index, text); visible = false }
                        onActiveFocusChanged: if (!activeFocus && visible) { App.markers.setNote(row.index, text); visible = false }
                        Keys.onEscapePressed: visible = false
                    }
                    Text { text: panel.fmt(row.time); color: Theme.ink3; font.pixelSize: 11; font.family: Theme.mono }
                }
                Btn {
                    anchors.right: parent.right; anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: "more"; iconSize: 16; implicitWidth: 28; implicitHeight: 28
                    visible: rowHover.hovered || rowMenu.opened
                    tip: "More"
                    onClicked: rowMenu.popup(this, 0, height)
                }
                SMenu {
                    id: rowMenu
                    implicitWidth: 200
                    SMenuItem { text: "Edit note"; glyph: "transcript"; onTriggered: row.edit() }
                    SMenuItem { text: "Set In here"; glyph: "in"; onTriggered: App.inPoint = row.time }
                    SMenuItem { text: "Set Out here"; glyph: "out"; onTriggered: App.outPoint = row.time }
                    MenuSeparator { contentItem: Rectangle { implicitHeight: 1; color: Theme.line } }
                    SMenuItem { text: "Delete"; glyph: "trash"; onTriggered: App.markers.remove(row.index) }
                }
            }

            // empty state
            Column {
                anchors.centerIn: parent
                width: parent.width - 48
                spacing: 8
                visible: App.markers.count === 0
                Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "marker"; size: 28; color: Theme.ink3 }
                Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "No markers"; color: Theme.ink2; font.pixelSize: Theme.fontBody }
                Text {
                    width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                    text: "Press M while reviewing to mark good takes, mistakes and notes."
                    color: Theme.ink3; font.pixelSize: 12
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.line }

        // export progress
        RowLayout {
            visible: App.busy
            Layout.fillWidth: true
            Layout.leftMargin: 14; Layout.rightMargin: 8; Layout.topMargin: 8
            spacing: 8
            Text { text: "Exporting"; color: Theme.ink2; font.pixelSize: 12 }
            Rectangle {
                Layout.fillWidth: true; height: 4; radius: 2; color: Theme.press
                Rectangle { width: parent.width * App.busyProgress; height: parent.height; radius: 2; color: Theme.accent }
            }
            Text { text: Math.round(App.busyProgress * 100) + "%"; color: Theme.ink2; font.pixelSize: 12; font.family: Theme.mono }
            Btn { glyph: "close"; iconSize: 15; implicitWidth: 26; implicitHeight: 26; tip: "Cancel export"; onClicked: App.cancelJob() }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 10
            spacing: 6
            Btn {
                Layout.fillWidth: true
                primary: true
                glyph: "scissors"
                text: "Export clip"
                readonly property bool ready: App.inPoint >= 0 && App.outPoint > App.inPoint
                enabled: !App.busy
                opacity: ready ? 1 : 0.55
                tip: ready ? "Copy In to Out without re-encoding" : "Set In (I) and Out (O) first"
                keys: "Ctrl+E"
                onClicked: ready ? App.exportClip(true) : panel.win.toast("Set an In point (I) and an Out point (O) first")
            }
            Btn {
                id: exportMore
                flat: false
                glyph: "export"
                text: "Export"
                tip: "More exports"
                onClicked: exportMenu.popup(exportMore, exportMore.width - exportMenu.implicitWidth, -exportMenu.implicitHeight - 4)
                SMenu {
                    id: exportMenu
                    implicitWidth: 290
                    SMenuItem { text: "Clip, frame-exact (re-encode)"; glyph: "scissors"; keys: "Ctrl+Shift+E"; enabled: !App.busy && App.inPoint >= 0 && App.outPoint > App.inPoint; onTriggered: App.exportClip(false) }
                    SMenuItem { text: "Markers for DaVinci Resolve (EDL)"; glyph: "film"; enabled: App.markers.count > 0; onTriggered: App.exportMarkersEdl(panel.mpv.fps) }
                    SMenuItem { text: "Markers as spreadsheet (CSV)"; glyph: "list"; enabled: App.markers.count > 0; onTriggered: App.exportMarkersCsv(panel.mpv.fps) }
                    SMenuItem { text: "Copy as YouTube chapters"; glyph: "copy"; enabled: App.markers.count > 0; onTriggered: App.copyYouTubeChapters(panel.mpv.duration) }
                    MenuSeparator { contentItem: Rectangle { implicitHeight: 1; color: Theme.line } }
                    SMenuItem { text: "Save current frame (PNG)"; glyph: "camera"; keys: "Ctrl+Shift+S"; enabled: panel.mpv.hasVideo; onTriggered: panel.win.grabFrame() }
                }
            }
        }
    }
}
