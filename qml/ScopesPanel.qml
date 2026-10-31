import QtQuick
import QtQuick.Layouts
import Slate

// Waveform, RGB parade, histogram and vectorscope for exposure and colour, plus a live audio meter.
Item {
    id: panel
    required property MpvObject mpv
    property bool shown: false
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 14; Layout.rightMargin: 8
            Layout.preferredHeight: 44
            Text { text: "Scopes"; color: Theme.ink; font.pixelSize: Theme.fontTitle; font.weight: Font.DemiBold }
            Item { Layout.fillWidth: true }
        }
        Segmented {
            id: seg
            Layout.fillWidth: true
            Layout.leftMargin: 10; Layout.rightMargin: 10
            options: [{ text: "Waveform" }, { text: "Parade" }, { text: "Histogram" }, { text: "Vector" }]
            current: App.setting("scopeMode", 0)
            onPicked: (i) => App.setSetting("scopeMode", i)
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: width * (seg.current === 3 ? 1 : 0.62)
            Layout.margins: 10
            radius: Theme.radius
            color: "#0d0e10"
            border.color: Theme.line
            clip: true
            ScopeItem {
                anchors.fill: parent; anchors.margins: 1
                source: panel.mpv
                mode: seg.current
                active: panel.shown && panel.mpv.hasVideo
            }
            Text { anchors.centerIn: parent; visible: !panel.mpv.hasVideo; text: "No video"; color: Theme.ink3; font.pixelSize: 12 }
        }
        Text {
            Layout.fillWidth: true
            Layout.leftMargin: 14; Layout.rightMargin: 14
            wrapMode: Text.WordWrap
            color: Theme.ink3; font.pixelSize: 11
            text: [
                "Brightness across the picture. Detail near 100 is clipping to white; near 0, crushed to black.",
                "Red, green and blue levels side by side. Matching heights on something white or grey means neutral white balance.",
                "How many pixels sit at each level. A pile at either edge means lost highlight or shadow detail.",
                "Colour saturation and hue. Skin tones of every complexion fall near the orange line."
            ][seg.current]
        }

        // ---- audio meter -----------------------------------------------------------
        Rectangle { Layout.fillWidth: true; Layout.topMargin: 16; height: 1; color: Theme.line }
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 14; Layout.rightMargin: 10
            Layout.preferredHeight: 40
            Text { text: "Audio"; color: Theme.ink; font.pixelSize: 13; font.weight: Font.DemiBold }
            Item { Layout.fillWidth: true }
            Segmented {
                visible: meter.channels >= 2
                Layout.preferredWidth: 156
                options: [{ text: "L+R" }, { text: "L" }, { text: "R" }]
                current: panel.mpv.listen
                onPicked: (i) => panel.mpv.listen = i
            }
        }
        Item {
            id: meter
            Layout.fillWidth: true
            Layout.leftMargin: 14; Layout.rightMargin: 14
            Layout.preferredHeight: channels >= 2 ? 44 : 30
            property var levels: []
            property var holds: [-120, -120]
            readonly property int channels: Math.min(2, (panel.mpv.info.channels || 0))
            readonly property real floorDb: -60
            function frac(db) { return Math.max(0, Math.min(1, (db - floorDb) / -floorDb)) }
            Timer {
                interval: 50; repeat: true
                running: panel.shown && panel.mpv.loaded && !panel.mpv.paused
                onTriggered: {
                    const l = panel.mpv.audioLevels()
                    const h = meter.holds.slice()
                    for (let i = 0; i < 2; ++i) {
                        const v = l.length > i ? l[i] : (l.length ? l[0] : -120)
                        h[i] = v > h[i] ? v : h[i] - 0.6
                    }
                    meter.levels = l; meter.holds = h
                }
                onRunningChanged: if (!running) { meter.levels = []; meter.holds = [-120, -120] }
            }
            Column {
                width: parent.width
                spacing: 6
                Repeater {
                    model: meter.channels >= 2 ? 2 : 1
                    delegate: Row {
                        required property int index
                        spacing: 8
                        Text { width: 10; text: meter.channels >= 2 ? (index === 0 ? "L" : "R") : "M"; color: Theme.ink3; font.pixelSize: 10; font.family: Theme.mono; anchors.verticalCenter: parent.verticalCenter }
                        Rectangle {
                            id: track
                            width: meter.width - 18; height: 6; radius: 3
                            color: Theme.press
                            readonly property real lv: meter.levels.length > index ? meter.levels[index] : (meter.levels.length ? meter.levels[0] : -120)
                            Rectangle {
                                width: parent.width * meter.frac(track.lv); height: parent.height; radius: 3
                                color: track.lv > -1 ? Theme.bad : (track.lv > -6 ? Theme.note : "#6f86b8")
                                Behavior on width { NumberAnimation { duration: 60 } }
                            }
                            Rectangle {
                                visible: meter.holds[index] > meter.floorDb
                                x: parent.width * meter.frac(meter.holds[index]) - 1
                                width: 2; height: parent.height; color: Theme.ink2
                            }
                        }
                    }
                }
                // scale
                Item {
                    width: meter.width; height: 12
                    Repeater {
                        model: [-60, -40, -20, -12, -6, 0]
                        delegate: Text {
                            required property int modelData
                            x: 18 + (meter.width - 18) * meter.frac(modelData) - implicitWidth / 2
                            text: modelData; color: Theme.ink3; font.pixelSize: 9; font.family: Theme.mono
                        }
                    }
                }
            }
        }
        Text {
            Layout.fillWidth: true
            Layout.leftMargin: 14; Layout.rightMargin: 14; Layout.topMargin: 10
            visible: meter.channels >= 2
            wrapMode: Text.WordWrap
            color: Theme.ink3; font.pixelSize: 11
            text: panel.mpv.listen === 0 ? "Peak level in dBFS. Listen to one side to check each mic on a two-channel recording."
                                         : "Playing only the " + (panel.mpv.listen === 1 ? "left" : "right") + " channel, through both speakers."
        }
        Item { Layout.fillHeight: true }
    }
    Connections {
        target: panel.mpv
        function onVideoInfoChanged() { if ((panel.mpv.info.channels || 0) < 2 && panel.mpv.listen !== 0) panel.mpv.listen = 0 }
    }
}
