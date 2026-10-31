import QtQuick
import QtQuick.Layouts
import Slate

// First screen: open buttons and recent files.
Item {
    id: es
    required property var win
    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(560, parent.width - 48)
        spacing: 0
        Image { Layout.alignment: Qt.AlignHCenter; source: "qrc:/Slate/assets/slate.png"; sourceSize: Qt.size(88, 88); width: 88; height: 88 }
        Text { Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 16; text: "Open something to review"; color: Theme.ink; font.pixelSize: 20; font.weight: Font.DemiBold }
        Text { Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 6; text: "Drop a clip, audio file or a whole folder anywhere in this window."; color: Theme.ink3; font.pixelSize: Theme.fontBody }
        Row {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 22
            spacing: 8
            Btn { primary: true; glyph: "file"; text: "Open file"; keys: "Ctrl+O"; tip: "Open a video or audio file"; implicitHeight: 36; onClicked: es.win.openFileDialog() }
            Btn { flat: false; glyph: "open"; text: "Open folder"; keys: "Ctrl+Shift+O"; tip: "Review every clip in a folder"; implicitHeight: 36; onClicked: es.win.openFolderDialog() }
        }

        RowLayout {
            visible: App.recentFiles.length > 0
            Layout.fillWidth: true
            Layout.topMargin: 36
            Text { text: "Recent"; color: Theme.ink2; font.pixelSize: 12; font.weight: Font.DemiBold }
            Item { Layout.fillWidth: true }
            Text {
                text: "Clear"; color: clearMa.containsMouse ? Theme.ink : Theme.ink3; font.pixelSize: 12
                MouseArea { id: clearMa; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: App.clearRecent() }
            }
        }
        Rectangle { visible: App.recentFiles.length > 0; Layout.fillWidth: true; Layout.topMargin: 8; height: 1; color: Theme.line }
        Repeater {
            model: App.recentFiles.slice(0, 7)
            delegate: Rectangle {
                id: rr
                required property string modelData
                readonly property string fname: modelData.split(/[\\/]/).pop()
                readonly property string folder: modelData.substring(0, modelData.length - fname.length - 1)
                Layout.fillWidth: true
                height: 44; radius: Theme.radius
                color: rh.hovered ? Theme.raise : "transparent"
                HoverHandler { id: rh }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: es.win.openMedia(rr.modelData) }
                Icon { x: 10; anchors.verticalCenter: parent.verticalCenter; name: /\.(mp3|wav|flac|m4a|aac|ogg|opus|aiff?|wma)$/i.test(rr.modelData) ? "music" : "film"; size: 18; color: Theme.ink3 }
                Column {
                    x: 40; anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 40 - 44
                    spacing: 2
                    Text { width: parent.width; text: rr.fname; elide: Text.ElideMiddle; color: Theme.ink; font.pixelSize: Theme.fontBody }
                    Text { width: parent.width; text: rr.folder; elide: Text.ElideMiddle; color: Theme.ink3; font.pixelSize: 11 }
                }
                Btn {
                    anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                    visible: rh.hovered
                    glyph: "close"; iconSize: 14; implicitWidth: 26; implicitHeight: 26
                    tip: "Remove from recent"
                    onClicked: App.removeRecent(rr.modelData)
                }
            }
        }
    }
}
