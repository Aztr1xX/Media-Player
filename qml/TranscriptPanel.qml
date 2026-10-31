import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Slate

// Offline transcript: click a line to jump there, search, export as subtitles or text.
Item {
    id: panel
    required property var mpv
    required property var win
    property string query: ""
    readonly property var lines: {
        const q = query.toLowerCase().trim()
        const all = Transcript.segments
        const out = []
        for (let k = 0; k < all.length; ++k) if (!q || all[k].text.toLowerCase().indexOf(q) >= 0) out.push({ i: k, start: all[k].start, text: all[k].text })
        return out
    }
    readonly property int playing: Transcript.state === "ready" ? Transcript.indexAt(mpv.position) : -1
    readonly property string stateText: {
        switch (Transcript.state) {
        case "downloading": return "Downloading the speech model (" + Transcript.modelSizeLabel(Transcript.model) + ", once)…"
        case "preparing": return "Reading audio…"
        case "transcribing": return "Transcribing on this computer…"
        default: return ""
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 14; Layout.rightMargin: 8
            Layout.preferredHeight: 44
            Text { text: "Transcript"; color: Theme.ink; font.pixelSize: Theme.fontTitle; font.weight: Font.DemiBold }
            Item { Layout.fillWidth: true }
            Btn {
                id: moreBtn
                visible: Transcript.state === "ready"
                glyph: "export"; tip: "Export transcript"
                onClicked: tMenu.popup(moreBtn, moreBtn.width - tMenu.implicitWidth, moreBtn.height + 2)
                SMenu {
                    id: tMenu
                    implicitWidth: 250
                    SMenuItem { text: "Save as subtitles (SRT)"; glyph: "subtitles"; onTriggered: { const p = Transcript.exportAs("srt"); panel.win.toast(p ? "Saved subtitles next to the clip" : "Couldn't save", p) } }
                    SMenuItem { text: "Save as text (TXT)"; glyph: "file"; onTriggered: { const p = Transcript.exportAs("txt"); panel.win.toast(p ? "Saved transcript next to the clip" : "Couldn't save", p) } }
                    MenuSeparator { contentItem: Rectangle { implicitHeight: 1; color: Theme.line } }
                    SMenuItem { text: "Transcribe again"; glyph: "loop"; onTriggered: Transcript.start(App.currentFile) }
                }
            }
        }

        // search
        TextField {
            visible: Transcript.state === "ready"
            Layout.fillWidth: true
            Layout.leftMargin: 10; Layout.rightMargin: 10; Layout.bottomMargin: 6
            implicitHeight: 32
            leftPadding: 32
            placeholderText: "Search the transcript"
            placeholderTextColor: Theme.ink3
            color: Theme.ink
            font.pixelSize: Theme.fontBody
            selectByMouse: true
            selectionColor: Theme.accent
            onTextChanged: panel.query = text
            Keys.onEscapePressed: { text = ""; focus = false }
            background: Rectangle { radius: Theme.radius; color: Theme.bg; border.color: parent.activeFocus ? Theme.accent : Theme.line }
            Icon { x: 9; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 15; color: Theme.ink3 }
        }

        ListView {
            id: list
            visible: Transcript.state === "ready"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: panel.lines
            spacing: 0
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            property bool follow: true
            onMovementStarted: follow = false
            Connections {
                target: panel
                function onPlayingChanged() {
                    if (!list.follow || panel.query) return
                    list.positionViewAtIndex(Math.max(0, panel.playing), ListView.Contain)
                }
            }
            delegate: Rectangle {
                id: line
                required property var modelData
                readonly property bool now: modelData.i === panel.playing
                width: list.width
                height: txt.implicitHeight + 16
                color: now ? Theme.accentSoft : (lh.hovered ? Theme.raise : "transparent")
                HoverHandler { id: lh }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { list.follow = true; panel.mpv.seekTo(line.modelData.start, true) } }
                Text {
                    id: ts
                    x: 14; y: 8
                    text: App.formatClock(line.modelData.start)
                    color: line.now ? Theme.accent : Theme.ink3
                    font.pixelSize: 11; font.family: Theme.mono
                }
                Text {
                    id: txt
                    x: 62; y: 7
                    width: parent.width - 62 - 14
                    text: line.modelData.text
                    color: line.now ? Theme.ink : Theme.ink2
                    font.pixelSize: Theme.fontBody
                    wrapMode: Text.Wrap
                    lineHeight: 1.15
                }
            }
            Text {
                anchors.centerIn: parent
                visible: panel.lines.length === 0
                text: panel.query ? "No lines contain “" + panel.query + "”" : "No speech found"
                color: Theme.ink3; font.pixelSize: 12
            }
        }

        // not transcribed / busy / error
        Item {
            visible: Transcript.state !== "ready"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Column {
                anchors.centerIn: parent
                width: parent.width - 48
                spacing: 10
                Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "transcript"; size: 28; color: Theme.ink3 }
                Text {
                    width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                    text: Transcript.state === "error" ? Transcript.error
                          : (panel.stateText || (Transcript.available ? "Turn speech into searchable, clickable text. It runs on this computer; nothing is uploaded." : "Transcription isn't included in this build."))
                    color: Transcript.state === "error" ? Theme.bad : Theme.ink2
                    font.pixelSize: 12
                }
                Rectangle {
                    visible: panel.stateText !== ""
                    width: parent.width; height: 4; radius: 2; color: Theme.press
                    Rectangle { width: parent.width * Transcript.progress; height: parent.height; radius: 2; color: Theme.accent; Behavior on width { NumberAnimation { duration: 200 } } }
                }
                Btn {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: panel.stateText === "" && Transcript.available
                    primary: true
                    text: Transcript.state === "error" ? "Try again" : "Transcribe"
                    enabled: panel.mpv.loaded && App.currentFile !== ""
                    onClicked: Transcript.start(App.currentFile)
                }
                Btn { anchors.horizontalCenter: parent.horizontalCenter; visible: panel.stateText !== ""; text: "Cancel"; flat: false; onClicked: Transcript.cancel() }
                Text {
                    visible: panel.stateText === "" && Transcript.available && !Transcript.modelReady
                    width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                    text: "The first time, Slate downloads a " + Transcript.modelSizeLabel(Transcript.model) + " speech model."
                    color: Theme.ink3; font.pixelSize: 11
                }
            }
        }
    }
}
