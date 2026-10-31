import QtQuick
import QtQuick.Layouts
import Slate

// Live peak meter for the audio playing now, left/right listening, and the clip's loudness.
// Kept apart from the scopes so it costs almost nothing while a clip plays.
Item {
    id: panel
    required property MpvObject mpv
    property bool shown: false
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        // ---- audio meter -----------------------------------------------------------
        Text {
            Layout.leftMargin: 14
            Layout.preferredHeight: 44
            verticalAlignment: Text.AlignVCenter
            text: "Audio levels"; color: Theme.ink; font.pixelSize: Theme.fontTitle; font.weight: Font.DemiBold
        }
        Segmented {
            visible: meter.channels >= 2
            Layout.fillWidth: true
            Layout.leftMargin: 10; Layout.rightMargin: 10; Layout.bottomMargin: 12
            options: [{ text: "Both channels" }, { text: "Left only" }, { text: "Right only" }]
            current: panel.mpv.listen
            onPicked: (i) => panel.mpv.listen = i
        }
        Item {
            id: meter
            Layout.fillWidth: true
            Layout.leftMargin: 14; Layout.rightMargin: 14
            Layout.preferredHeight: channels >= 2 ? 50 : 34
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
                            width: meter.width - 18; height: 8; radius: 4
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

        Rectangle { Layout.fillWidth: true; Layout.topMargin: 16; Layout.bottomMargin: 8; height: 1; color: Theme.line }
        Text { Layout.leftMargin: 14; text: "WHOLE CLIP"; color: Theme.ink3; font.pixelSize: 10; font.letterSpacing: 0.8 }
        GridLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 14; Layout.rightMargin: 14; Layout.topMargin: 6
            columns: 2; rowSpacing: 6; columnSpacing: 10
            readonly property var lo: Media.loudness
            Text { text: "Loudness"; color: Theme.ink2; font.pixelSize: 12; Layout.preferredWidth: 96 }
            Text { text: parent.lo.integrated !== undefined ? parent.lo.integrated.toFixed(1) + " LUFS" : (parent.lo.measuring ? "Measuring…" : "–"); color: Theme.ink; font.pixelSize: 12 }
            Text { text: "True peak"; color: Theme.ink2; font.pixelSize: 12 }
            Text { text: parent.lo.truePeak !== undefined ? parent.lo.truePeak.toFixed(1) + " dBTP" : "–"; color: parent.lo.truePeak > -1 ? Theme.bad : Theme.ink; font.pixelSize: 12 }
            Text { text: "Range"; color: Theme.ink2; font.pixelSize: 12 }
            Text { text: parent.lo.range !== undefined ? parent.lo.range.toFixed(1) + " LU" : "–"; color: Theme.ink; font.pixelSize: 12 }
        }
        Item { Layout.fillHeight: true }
    }
    Connections {
        target: panel.mpv
        function onVideoInfoChanged() { if ((panel.mpv.info.channels || 0) < 2 && panel.mpv.listen !== 0) panel.mpv.listen = 0 }
    }
}
