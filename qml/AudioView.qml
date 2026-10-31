import QtQuick
import Slate

// Shown instead of a picture for audio files: large waveform, title and loudness.
Item {
    id: av
    required property var mpv
    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 1100)
        spacing: 18
        Column {
            width: parent.width
            spacing: 4
            Text {
                width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideMiddle
                text: av.mpv.mediaTitle || App.currentName
                color: Theme.ink; font.pixelSize: 20; font.weight: Font.DemiBold
            }
            Text {
                width: parent.width; horizontalAlignment: Text.AlignHCenter
                text: [App.formatClock(av.mpv.duration), (Media.probe.audioCodec || "").toUpperCase(),
                       Media.probe.sampleRate ? (Media.probe.sampleRate / 1000) + " kHz" : "",
                       Media.probe.channels === 1 ? "Mono" : (Media.probe.channels === 2 ? "Stereo" : (Media.probe.channels ? Media.probe.channels + " channels" : ""))]
                      .filter(x => x).join("   ·   ")
                color: Theme.ink3; font.pixelSize: 12
            }
        }
        Item {
            id: wave
            width: parent.width; height: Math.min(260, av.height * 0.4)
            WaveformItem { id: wf; anchors.fill: parent; color: "#8b94a1"; peakColor: "#3b4048" }
            Rectangle {
                width: av.mpv.duration > 0 ? parent.width * av.mpv.position / av.mpv.duration : 0
                height: parent.height
                color: Qt.rgba(0.31, 0.55, 1, 0.16)
            }
            Rectangle { x: av.mpv.duration > 0 ? parent.width * av.mpv.position / av.mpv.duration - 1 : 0; width: 2; height: parent.height; color: Theme.ink }
            Text { anchors.centerIn: parent; visible: !wf.hasData; text: Media.waveformReady ? "No audio" : "Reading audio…"; color: Theme.ink3; font.pixelSize: 12 }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onPressed: (m) => av.mpv.seekTo(m.x / width * av.mpv.duration, false)
                onPositionChanged: (m) => { if (pressed) av.mpv.seekTo(Math.max(0, m.x) / width * av.mpv.duration, false) }
                onReleased: (m) => av.mpv.seekTo(Math.max(0, m.x) / width * av.mpv.duration, true)
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10
            visible: Media.loudness.integrated !== undefined || Media.loudness.measuring === true
            component Stat: Rectangle {
                property string label
                property string value
                width: 128; height: 54; radius: Theme.radius
                color: Theme.raise; border.color: Theme.line
                Column {
                    anchors.centerIn: parent; spacing: 3
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: value; color: Theme.ink; font.pixelSize: 16; font.family: Theme.mono }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: label; color: Theme.ink3; font.pixelSize: 10; font.letterSpacing: 0.6 }
                }
            }
            Stat { label: "INTEGRATED"; value: Media.loudness.integrated !== undefined ? Media.loudness.integrated.toFixed(1) + " LUFS" : "…" }
            Stat { label: "RANGE"; value: Media.loudness.range !== undefined ? Media.loudness.range.toFixed(1) + " LU" : "…" }
            Stat { label: "TRUE PEAK"; value: Media.loudness.truePeak !== undefined ? Media.loudness.truePeak.toFixed(1) + " dB" : "…" }
        }
    }
}
