import QtQuick
import Take
import QtQuick.Controls
import QtQuick.Layouts


// Marker list (click to jump, double-click note to edit, colour bar cycles kind)
// plus export actions.
Item {
    id: panel
    required property var mpv
    function fmt(t) { return mpv.hasVideo && mpv.fps > 0 ? App.formatTimecode(t, mpv.fps) : App.formatClock(t) }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Text {
            Layout.fillWidth: true
            Layout.margins: 10
            Layout.bottomMargin: 4
            wrapMode: Text.WordWrap
            color: Theme.muted; font.pixelSize: 11
            text: App.markers.count === 0
                  ? "No markers yet. Press M to drop one at the playhead."
                  : "Click to jump · double-click a note to edit · colour bar cycles Note / Good / Mistake"
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: App.markers
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            delegate: Rectangle {
                id: row
                required property int index
                required property double time
                required property string note
                required property int kind
                width: list.width
                height: 48
                color: rowHover.hovered ? Theme.raise : "transparent"
                HoverHandler { id: rowHover }

                MouseArea {
                    anchors.fill: parent
                    onClicked: { mpv.paused = true; mpv.seekTo(row.time, true) }
                    onDoubleClicked: { editor.text = row.note; editor.visible = true; editor.forceActiveFocus(); editor.selectAll() }
                }
                Rectangle {
                    x: 10; y: 8; width: 6; height: parent.height - 16; radius: 2
                    color: Theme.kindColor(row.kind)
                    MouseArea {
                        anchors.fill: parent; anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: App.markers.cycleKind(row.index)
                    }
                    ToolTip.visible: kindHover.hovered
                    ToolTip.text: Theme.kindName(row.kind) + ". Click to change"
                    HoverHandler { id: kindHover }
                }
                Column {
                    x: 26; y: 7
                    width: parent.width - 26 - 36
                    spacing: 2
                    Text {
                        visible: !editor.visible
                        width: parent.width
                        text: row.note; color: Theme.ink; font.pixelSize: 13; elide: Text.ElideRight
                    }
                    TextField {
                        id: editor
                        visible: false
                        width: parent.width
                        height: 22
                        padding: 2
                        font.pixelSize: 13
                        color: Theme.ink
                        selectByMouse: true
                        background: Rectangle { color: Theme.bg; border.color: Theme.accent; radius: 3 }
                        onAccepted: { App.markers.setNote(row.index, text); visible = false }
                        onActiveFocusChanged: if (!activeFocus && visible) { App.markers.setNote(row.index, text); visible = false }
                        Keys.onEscapePressed: visible = false
                    }
                    Text { text: panel.fmt(row.time); color: Theme.muted; font.pixelSize: 11; font.family: Theme.mono }
                }
                IconButton {
                    anchors.right: parent.right; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: "×"; implicitWidth: 26; implicitHeight: 24
                    visible: rowHover.hovered
                    tip: "Delete marker"
                    onClicked: App.markers.remove(row.index)
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.line }

        // export progress
        RowLayout {
            visible: App.busy
            Layout.fillWidth: true
            Layout.margins: 10
            ProgressBar { Layout.fillWidth: true; value: App.busyProgress }
            IconButton { text: "Cancel"; onClicked: App.cancelJob() }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.margins: 10
            columns: 2
            columnSpacing: 6
            rowSpacing: 6
            IconButton {
                Layout.fillWidth: true; primary: true
                text: "Export In→Out"
                enabled: !App.busy && App.inPoint >= 0 && App.outPoint > App.inPoint
                tip: "Lossless copy, instant. Start snaps to the keyframe before In  (Ctrl+E)"
                onClicked: App.exportClip(true)
            }
            IconButton {
                Layout.fillWidth: true
                text: "Exact (re-encode)"
                enabled: !App.busy && App.inPoint >= 0 && App.outPoint > App.inPoint
                tip: "Frame-exact H.264 copy at high quality  (Ctrl+Shift+E)"
                onClicked: App.exportClip(false)
            }
            IconButton { Layout.fillWidth: true; text: "Markers → EDL"; enabled: App.markers.count > 0; tip: "For DaVinci Resolve: Timelines > Import > Timeline Markers from EDL"; onClicked: App.exportMarkersEdl(mpv.fps) }
            IconButton { Layout.fillWidth: true; text: "Markers → CSV"; enabled: App.markers.count > 0; tip: "Spreadsheet of timecodes and notes"; onClicked: App.exportMarkersCsv(mpv.fps) }
            IconButton { Layout.fillWidth: true; Layout.columnSpan: 2; text: "Copy YouTube chapters"; enabled: App.markers.count > 0; tip: "Starts at 0:00, needs 3+ chapters of 10 s or more"; onClicked: App.copyYouTubeChapters(mpv.duration) }
        }
    }
}
