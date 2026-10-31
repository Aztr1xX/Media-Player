import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Slate

// Settings: general, playback, exports, transcription, shortcuts, Windows and about.
Popup {
    id: dlg
    required property var win
    property int page: 0
    property string capturingId: ""
    readonly property bool capturing: capturingId !== ""
    function openAt(p) { page = p; open() }

    modal: true
    focus: true
    anchors.centerIn: Overlay.overlay
    width: Math.min(860, parent.width - 60)
    height: Math.min(620, parent.height - 60)
    padding: 0
    closePolicy: capturing ? Popup.NoAutoClose : (Popup.CloseOnEscape | Popup.CloseOnPressOutside)
    Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.5) }
    background: Rectangle { color: Theme.panel; radius: Theme.radiusLg; border.color: Theme.lineStrong }
    onClosed: capturingId = ""

    readonly property var pages: [
        { text: "General", icon: "settings" },
        { text: "Playback", icon: "play" },
        { text: "Exports", icon: "export" },
        { text: "Transcription", icon: "transcript" },
        { text: "Shortcuts", icon: "keyboard" },
        { text: "Windows", icon: "sidebar" },
        { text: "About", icon: "info" }
    ]

    component Heading: Text { color: Theme.ink; font.pixelSize: 18; font.weight: Font.DemiBold; Layout.bottomMargin: 8 }
    component Note: Text { Layout.fillWidth: true; color: Theme.ink3; font.pixelSize: 12; wrapMode: Text.WordWrap }
    component Toggle: SSwitch {
        property string key
        property bool fallback: true
        Layout.fillWidth: true
        checked: App.setting(key, fallback)
        onToggled: App.setSetting(key, checked)
    }
    component Divider: Rectangle { Layout.fillWidth: true; Layout.topMargin: 6; Layout.bottomMargin: 6; height: 1; color: Theme.line }

    FolderDialog {
        id: exportFolderDialog
        title: "Choose where exports go"
        onAccepted: { App.setSetting("exportFolder", App.localPath(selectedFolder)); exportLabel.text = App.exportFolderLabel() }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // navigation
        Rectangle {
            Layout.preferredWidth: 200
            Layout.fillHeight: true
            color: Theme.chrome
            radius: Theme.radiusLg
            Rectangle { anchors.right: parent.right; width: Theme.radiusLg; height: parent.height; color: Theme.chrome }
            Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.line }
            Column {
                anchors.fill: parent; anchors.margins: 10; anchors.topMargin: 16
                spacing: 2
                Text { leftPadding: 8; bottomPadding: 10; text: "Settings"; color: Theme.ink; font.pixelSize: Theme.fontTitle; font.weight: Font.DemiBold }
                Repeater {
                    model: dlg.pages
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: parent.width; height: 34; radius: Theme.radius
                        color: dlg.page === index ? Theme.hover : (nm.containsMouse ? Theme.raise : "transparent")
                        Row {
                            x: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                            Icon { name: modelData.icon; size: 16; color: dlg.page === index ? Theme.ink : Theme.ink2; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: modelData.text; color: dlg.page === index ? Theme.ink : Theme.ink2; font.pixelSize: Theme.fontBody; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea { id: nm; anchors.fill: parent; hoverEnabled: true; onClicked: { dlg.capturingId = ""; dlg.page = index } }
                    }
                }
            }
        }

        // pages
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: dlg.page

            // General
            Flickable {
                contentHeight: g.implicitHeight + 48; clip: true; boundsBehavior: Flickable.StopAtBounds
                ColumnLayout {
                    id: g
                    x: 28; y: 24; width: parent.width - 56
                    spacing: 12
                    Heading { text: "General" }
                    Toggle { key: "singleWindow"; text: "Open files in the window that's already open" }
                    Note { text: "When off, every file you open from Explorer gets its own Slate window. Takes effect next time Slate starts." }
                    Divider {}
                    Toggle { key: "resume"; text: "Resume long files where you left off" }
                    Toggle { key: "rememberVolume"; text: "Remember the volume" }
                    Toggle { key: "autoAdvance"; fallback: false; text: "Play the next clip in the folder when one ends" }
                    Divider {}
                    RowLayout {
                        Layout.fillWidth: true
                        Text { Layout.fillWidth: true; text: "Recent files"; color: Theme.ink; font.pixelSize: Theme.fontBody }
                        Btn { flat: false; text: "Clear list"; enabled: App.recentFiles.length > 0; onClicked: App.clearRecent() }
                    }
                }
            }

            // Playback
            Flickable {
                contentHeight: pb.implicitHeight + 48; clip: true; boundsBehavior: Flickable.StopAtBounds
                ColumnLayout {
                    id: pb
                    x: 28; y: 24; width: parent.width - 56
                    spacing: 12
                    Heading { text: "Playback" }
                    SSwitch {
                        Layout.fillWidth: true
                        text: "Use the graphics card to decode video"
                        checked: App.setting("hwdec", true)
                        onToggled: { App.setSetting("hwdec", checked); dlg.win.mpvItem().setMpvProperty("hwdec", checked ? "auto-safe" : "no") }
                    }
                    Note { text: "Smoother 4K and HEVC playback with less CPU. Turn it off only if a file shows glitches." }
                    Divider {}
                    Text { text: "Skip silences"; color: Theme.ink; font.pixelSize: Theme.fontBody }
                    Note { text: "Ctrl+Shift+K jumps over pauses longer than about a second while playing. Handy for lectures and long talking-head recordings." }
                    Divider {}
                    Text { text: "mpv settings"; color: Theme.ink; font.pixelSize: Theme.fontBody }
                    Note { text: "Slate plays through mpv. Advanced users can put an mpv.conf and scripts in Slate's mpv folder; they load when Slate starts." }
                    Btn { flat: false; glyph: "open"; text: "Open mpv folder"; onClicked: App.openFolder(App.mpvConfigDir()) }
                }
            }

            // Exports
            Flickable {
                contentHeight: ex.implicitHeight + 48; clip: true; boundsBehavior: Flickable.StopAtBounds
                ColumnLayout {
                    id: ex
                    x: 28; y: 24; width: parent.width - 56
                    spacing: 12
                    Heading { text: "Exports" }
                    Text { text: "Save clips, markers and frames to"; color: Theme.ink; font.pixelSize: Theme.fontBody }
                    Rectangle {
                        Layout.fillWidth: true; height: 36; radius: Theme.radius
                        color: Theme.bg; border.color: Theme.line
                        Text { id: exportLabel; x: 12; width: parent.width - 24; anchors.verticalCenter: parent.verticalCenter; text: App.exportFolderLabel(); color: Theme.ink2; font.pixelSize: 12; elide: Text.ElideMiddle }
                    }
                    Row {
                        spacing: 8
                        Btn { flat: false; glyph: "open"; text: "Choose folder…"; onClicked: exportFolderDialog.open() }
                        Btn { flat: false; text: "Next to the original"; onClicked: { App.setSetting("exportFolder", ""); exportLabel.text = App.exportFolderLabel() } }
                    }
                    Divider {}
                    Text { text: "How clip export works"; color: Theme.ink; font.pixelSize: Theme.fontBody }
                    Note { text: "Export clip (Ctrl+E) copies the video untouched, so it's instant with no quality loss, but it starts on the keyframe at or before your In point. Frame-exact export (Ctrl+Shift+E) re-encodes to high-quality H.264 so it starts exactly on In." }
                    Divider {}
                    Text { text: "Markers in DaVinci Resolve"; color: Theme.ink; font.pixelSize: Theme.fontBody }
                    Note { text: "Export markers as EDL, then in Resolve right-click the timeline in the Media Pool and choose Timelines > Import > Timeline Markers from EDL. Notes come in yellow, good takes green and mistakes red." }
                }
            }

            // Transcription
            Flickable {
                contentHeight: tr.implicitHeight + 48; clip: true; boundsBehavior: Flickable.StopAtBounds
                ColumnLayout {
                    id: tr
                    x: 28; y: 24; width: parent.width - 56
                    spacing: 12
                    Heading { text: "Transcription" }
                    Note { text: Transcript.available ? "Transcripts are made on this computer with whisper.cpp. Nothing is uploaded. The model downloads once, the first time you use it." : "Transcription isn't included in this build of Slate." }
                    Text { text: "Speech model"; color: Theme.ink; font.pixelSize: Theme.fontBody; Layout.topMargin: 6 }
                    Repeater {
                        model: [
                            { id: "base.en", name: "Fast, English", desc: "142 MB. Good for clear speech and lectures." },
                            { id: "small.en", name: "Accurate, English", desc: "466 MB. Better with accents and noise; about 3 times slower." },
                            { id: "base", name: "Fast, any language", desc: "142 MB. Detects the language automatically." },
                            { id: "small", name: "Accurate, any language", desc: "466 MB. Detects the language automatically." }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            height: 54; radius: Theme.radius
                            color: Transcript.model === modelData.id ? Theme.accentSoft : (mm.containsMouse ? Theme.raise : "transparent")
                            border.color: Transcript.model === modelData.id ? Theme.accent : Theme.line
                            Column {
                                x: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 3
                                Text { text: modelData.name; color: Theme.ink; font.pixelSize: Theme.fontBody }
                                Text { text: modelData.desc; color: Theme.ink3; font.pixelSize: 12 }
                            }
                            MouseArea { id: mm; anchors.fill: parent; hoverEnabled: true; onClicked: { Transcript.model = modelData.id; App.setSetting("whisperModel", modelData.id) } }
                        }
                    }
                }
            }

            // Shortcuts
            Item {
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 24; anchors.leftMargin: 28; anchors.rightMargin: 20
                    spacing: 10
                    RowLayout {
                        Layout.fillWidth: true
                        Heading { text: "Keyboard shortcuts"; Layout.bottomMargin: 0 }
                        Item { Layout.fillWidth: true }
                        Btn { Layout.rightMargin: 36; flat: false; text: "Reset all"; onClicked: { for (const a of dlg.win.actionList) App.setSetting("keys/" + a.id, ""); dlg.win.keymapRevision++ } }
                    }
                    TextField {
                        id: keySearch
                        Layout.fillWidth: true
                        implicitHeight: 32
                        leftPadding: 32
                        placeholderText: "Search shortcuts"
                        placeholderTextColor: Theme.ink3
                        color: Theme.ink; font.pixelSize: Theme.fontBody
                        selectByMouse: true; selectionColor: Theme.accent
                        background: Rectangle { radius: Theme.radius; color: Theme.bg; border.color: keySearch.activeFocus ? Theme.accent : Theme.line }
                        Icon { x: 9; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 15; color: Theme.ink3 }
                    }
                    Note { text: dlg.capturing ? "Press the new key combination. Esc cancels, Backspace removes the shortcut." : "Click a shortcut to change it." }
                    ListView {
                        id: keyList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar {}
                        model: { dlg.win.keymapRevision; const q = keySearch.text.toLowerCase(); return dlg.win.actionList.filter(a => !q || (a.name + " " + a.category + " " + dlg.win.keysLabel(a)).toLowerCase().indexOf(q) >= 0) }
                        delegate: Column {
                            id: kr
                            required property var modelData
                            required property int index
                            readonly property bool editing: dlg.capturingId === modelData.id
                            readonly property bool firstOfGroup: index === 0 || keyList.model[index - 1].category !== modelData.category
                            width: keyList.width - 10
                            Text { visible: kr.firstOfGroup; text: kr.modelData.category.toUpperCase(); color: Theme.ink3; font.pixelSize: 10; font.letterSpacing: 0.8; topPadding: kr.index === 0 ? 4 : 14; bottomPadding: 4 }
                            Rectangle {
                            width: parent.width; height: 36; radius: Theme.radius
                            color: krm.containsMouse || kr.editing ? Theme.raise : "transparent"
                            Text { x: 10; anchors.verticalCenter: parent.verticalCenter; text: kr.modelData.name; color: Theme.ink; font.pixelSize: Theme.fontBody }
                            Rectangle {
                                anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                                width: Math.max(60, kl.implicitWidth + 16); height: 24; radius: 4
                                color: kr.editing ? Theme.accentSoft : Theme.bg
                                border.color: kr.editing ? Theme.accent : Theme.lineStrong
                                Text {
                                    id: kl; anchors.centerIn: parent
                                    text: { dlg.win.keymapRevision; return kr.editing ? "Press keys…" : (dlg.win.keysLabel(kr.modelData) || "None") }
                                    color: kr.editing ? Theme.ink : Theme.ink2; font.pixelSize: 12
                                }
                            }
                            MouseArea { id: krm; anchors.fill: parent; hoverEnabled: true; onClicked: { dlg.capturingId = kr.modelData.id; capture.forceActiveFocus() } }
                            }
                        }
                    }
                }
                Item {
                    id: capture
                    focus: dlg.capturing
                    Keys.onPressed: (e) => {
                        if (!dlg.capturing) return
                        e.accepted = true
                        if (e.key === Qt.Key_Escape) { dlg.capturingId = ""; return }
                        if (e.key === Qt.Key_Backspace || e.key === Qt.Key_Delete) {
                            App.setSetting("keys/" + dlg.capturingId, "-"); dlg.capturingId = ""; dlg.win.keymapRevision++; return
                        }
                        const k = App.keyText(e.key, e.modifiers)
                        if (!k) return
                        // Take the combination away from any other action that had it.
                        for (const a of dlg.win.actionList) {
                            if (a.id === dlg.capturingId) continue
                            const ks = dlg.win.keysFor(a)
                            if (ks.indexOf(k) >= 0) { const rest = ks.filter(x => x !== k); App.setSetting("keys/" + a.id, rest.length ? rest.join("|") : "-") }
                        }
                        App.setSetting("keys/" + dlg.capturingId, k)
                        dlg.capturingId = ""
                        dlg.win.keymapRevision++
                    }
                }
            }

            // Windows
            Flickable {
                contentHeight: wn.implicitHeight + 48; clip: true; boundsBehavior: Flickable.StopAtBounds
                ColumnLayout {
                    id: wn
                    x: 28; y: 24; width: parent.width - 56
                    spacing: 12
                    Heading { text: "Windows" }
                    Text { text: "Make Slate your default player"; color: Theme.ink; font.pixelSize: Theme.fontBody }
                    Note { text: "Windows only lets you choose default apps in Settings. The button opens Slate's page there: pick \"Set default\" at the top, or choose Slate for each file type you want." }
                    Btn { primary: true; glyph: "external"; text: "Open Default apps"; enabled: App.isWindows; onClicked: App.openDefaultAppsSettings() }
                    Note { visible: !App.isWindows; text: "Available when Slate is installed on Windows." }
                    Divider {}
                    Text { text: "Right-click menu"; color: Theme.ink; font.pixelSize: Theme.fontBody }
                    Note { text: "The installer adds \"Open with Slate\" for video and audio files, and \"Review folder in Slate\" for folders." }
                }
            }

            // About
            Flickable {
                contentHeight: ab.implicitHeight + 48; clip: true; boundsBehavior: Flickable.StopAtBounds
                ColumnLayout {
                    id: ab
                    x: 28; y: 24; width: parent.width - 56
                    spacing: 10
                    Image { source: "qrc:/Slate/assets/slate.png"; sourceSize: Qt.size(56, 56); Layout.preferredWidth: 56; Layout.preferredHeight: 56 }
                    Text { text: "Slate " + App.version; color: Theme.ink; font.pixelSize: 18; font.weight: Font.DemiBold }
                    Note { text: "A media player for reviewing clips and audio before you edit them." }
                    Divider {}
                    Note { text: "Built with Qt (LGPL v3), libmpv (LGPL v2.1+) and FFmpeg, which runs as a separate program. Transcription uses whisper.cpp (MIT) and OpenAI's Whisper models (MIT). URL playback uses yt-dlp (Unlicense)." }
                    Note { text: "Slate itself: personal use, all rights reserved." }
                }
            }
        }
    }

    Btn {
        anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 10
        glyph: "close"; tip: "Close"; keys: "Esc"
        onClicked: dlg.close()
    }
}
