import QtQuick
import Take
import QtQuick.Controls
import QtQuick.Layouts


// Media inspector: what the file actually is.
Flickable {
    id: f
    required property var mpv
    clip: true
    contentHeight: grid.implicitHeight + 20
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {}

    readonly property var i: mpv.info
    function val(k, suffix) { return i[k] !== undefined ? String(i[k]) + (suffix || "") : "–" }

    GridLayout {
        id: grid
        x: 12; y: 10
        width: f.width - 24
        columns: 2
        columnSpacing: 14
        rowSpacing: 7

        component Key: Text { color: Theme.muted; font.pixelSize: 12 }
        component Val: Text { color: Theme.ink; font.pixelSize: 12; Layout.fillWidth: true; wrapMode: Text.WrapAnywhere }

        Key { text: "File" }        Val { text: App.currentName || "–" }
        Key { text: "Container" }   Val { text: f.val("container") }
        Key { text: "Size" }        Val { text: f.i.fileSize !== undefined ? App.formatBytes(f.i.fileSize) : "–" }
        Key { text: "Duration" }    Val { text: mpv.duration > 0 ? App.formatClock(mpv.duration) + "  (" + mpv.duration.toFixed(3) + " s)" : "–" }
        Key { text: "Video" }       Val { text: mpv.hasVideo ? f.val("videoCodec") : "none" }
        Key { text: "Resolution" }  Val { text: f.i.width !== undefined ? f.i.width + " × " + f.i.height : "–" }
        Key { text: "Frame rate" }  Val { text: mpv.fps > 0 ? mpv.fps.toFixed(3).replace(/\.?0+$/, "") + " fps" : "–" }
        Key { text: "Pixel format" } Val { text: f.val("pixelFormat") }
        Key { text: "Colour" }      Val { text: f.i.primaries !== undefined ? f.i.primaries + " / " + f.val("gamma") : "–" }
        Key { text: "HDR" }         Val { text: (f.i.gamma === "pq" || f.i.gamma === "hlg") ? "Yes (" + f.i.gamma + "), tone-mapped for display" : (f.i.gamma !== undefined ? "No" : "–") }
        Key { text: "Decoder" }     Val { text: f.i.hwdec && f.i.hwdec !== "no" ? "Hardware (" + f.i.hwdec + ")" : (mpv.hasVideo ? "Software" : "–") }
        Key { text: "Audio" }       Val { text: f.val("audioCodec") }
        Key { text: "Sample rate" } Val { text: f.i.sampleRate !== undefined ? (f.i.sampleRate / 1000) + " kHz" : "–" }
        Key { text: "Channels" }    Val { text: f.val("channels") }
    }
}
