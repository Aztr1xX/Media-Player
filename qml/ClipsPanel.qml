import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Slate

// Every clip in the current folder, in natural order, with thumbnails, durations and star ratings.
Item {
    id: panel
    required property var win
    property int minStars: 0
    readonly property var shown: {
        App.ratingsRevision
        return App.queue.filter(f => minStars === 0 || App.rating(f) >= minStars)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 14; Layout.rightMargin: 8
            Layout.preferredHeight: 44
            Text { text: "Clips"; color: Theme.ink; font.pixelSize: Theme.fontTitle; font.weight: Font.DemiBold }
            Text { text: App.queue.length > 0 ? (panel.minStars ? panel.shown.length + " of " + App.queue.length : App.queue.length) : ""; color: Theme.ink3; font.pixelSize: Theme.fontBody }
            Item { Layout.fillWidth: true }
            Btn {
                id: filterBtn
                glyph: "filter"
                text: panel.minStars ? panel.minStars + "★+" : ""
                active: panel.minStars > 0
                tip: "Show only rated clips"
                onClicked: filterMenu.popup(filterBtn, filterBtn.width - filterMenu.implicitWidth, filterBtn.height + 2)
                SMenu {
                    id: filterMenu
                    implicitWidth: 190
                    SMenuItem { text: "All clips"; checkable: true; checked: panel.minStars === 0; onTriggered: panel.minStars = 0 }
                    Repeater {
                        model: [5, 4, 3, 2, 1]
                        delegate: SMenuItem {
                            required property int modelData
                            text: modelData === 5 ? "★★★★★ only" : "★".repeat(modelData) + " and up"
                            checkable: true; checked: panel.minStars === modelData
                            onTriggered: panel.minStars = modelData
                        }
                    }
                }
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: panel.shown
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}

            delegate: Rectangle {
                id: row
                required property string modelData
                required property int index
                readonly property bool current: modelData === App.currentFile
                readonly property int stars: { App.ratingsRevision; return App.rating(modelData) }
                width: list.width; height: 58
                color: current ? Theme.accentSoft : (hov.hovered ? Theme.raise : "transparent")
                HoverHandler { id: hov }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (m) => { if (m.button === Qt.RightButton) clipMenu.popup(); else if (!row.current) panel.win.openMedia(row.modelData) }
                }
                Rectangle { visible: row.current; width: 2; height: parent.height; color: Theme.accent }

                Rectangle {
                    id: thumb
                    x: 12; anchors.verticalCenter: parent.verticalCenter
                    width: 72; height: 40; radius: 4
                    color: Theme.bg
                    clip: true
                    readonly property string src: { Media.queueRevision; return Media.thumbFor(row.modelData) }
                    Image { anchors.fill: parent; source: thumb.src; fillMode: Image.PreserveAspectCrop; visible: thumb.src !== ""; asynchronous: true }
                    Icon { anchors.centerIn: parent; visible: thumb.src === ""; name: /\.(mp3|wav|flac|m4a|aac|ogg|opus|aiff?|wma)$/i.test(row.modelData) ? "music" : "film"; size: 18; color: Theme.ink3 }
                    Rectangle {
                        readonly property double d: { Media.queueRevision; return Media.durationFor(row.modelData) }
                        visible: d > 0
                        anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 3
                        width: dl.implicitWidth + 6; height: 14; radius: 3
                        color: Qt.rgba(0, 0, 0, 0.7)
                        Text { id: dl; anchors.centerIn: parent; text: App.formatClock(parent.d); color: "white"; font.pixelSize: 9; font.family: Theme.mono }
                    }
                }
                Column {
                    anchors.left: thumb.right; anchors.leftMargin: 10
                    anchors.right: parent.right; anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5
                    Text {
                        width: parent.width
                        text: row.modelData.split(/[\\/]/).pop()
                        elide: Text.ElideMiddle
                        color: row.current ? Theme.ink : Theme.ink
                        font.pixelSize: Theme.fontBody
                        font.weight: row.current ? Font.DemiBold : Font.Normal
                    }
                    Row {
                        spacing: 1
                        Repeater {
                            model: 5
                            delegate: Icon {
                                required property int index
                                name: index < row.stars ? "star-filled" : "star"
                                size: 13
                                color: index < row.stars ? Theme.note : (hov.hovered ? Theme.ink3 : "#3a3e45")
                                MouseArea {
                                    anchors.fill: parent; anchors.margins: -2
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: App.setRating(row.modelData, row.stars === index + 1 ? 0 : index + 1)
                                }
                            }
                        }
                    }
                }
                SMenu {
                    id: clipMenu
                    implicitWidth: 230
                    SMenuItem { text: "Open"; glyph: "play"; enabled: !row.current; onTriggered: panel.win.openMedia(row.modelData) }
                    SMenuItem { text: "Compare with current clip"; glyph: "compare"; enabled: !row.current && App.currentFile !== ""; onTriggered: panel.win.startCompare(row.modelData) }
                    SMenuItem { text: App.isWindows ? "Show in Explorer" : "Show in folder"; glyph: "open"; onTriggered: App.revealInFolder(row.modelData) }
                    MenuSeparator { contentItem: Rectangle { implicitHeight: 1; color: Theme.line } }
                    SMenuItem { text: "Clear rating"; enabled: row.stars > 0; onTriggered: App.setRating(row.modelData, 0) }
                }
            }

            Column {
                anchors.centerIn: parent
                width: parent.width - 48
                spacing: 8
                visible: panel.shown.length === 0
                Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "list"; size: 28; color: Theme.ink3 }
                Text {
                    width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                    text: App.queue.length === 0 ? "Open a clip and the rest of its folder appears here." : "No clips with that rating yet. Press 1 to 5 to rate the clip you're watching."
                    color: Theme.ink3; font.pixelSize: 12
                }
            }
        }
    }
}
