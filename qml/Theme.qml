pragma Singleton
import QtQuick

// One place for colours, sizes and type. Neutral graphite greys with a single blue accent,
// so the picture is always the most colourful thing on screen.
QtObject {
    readonly property color bg: "#0e0f11"        // behind the video
    readonly property color chrome: "#141518"    // header, transport
    readonly property color panel: "#17181b"     // side panel
    readonly property color raise: "#1e2024"     // cards, inputs
    readonly property color hover: "#25282d"
    readonly property color press: "#2c3036"
    readonly property color line: "#26292e"
    readonly property color lineStrong: "#33373d"

    readonly property color ink: "#e8eaed"
    readonly property color ink2: "#a4aab3"
    readonly property color ink3: "#6e747e"

    readonly property color accent: "#4f8cff"
    readonly property color accentHover: "#6a9eff"
    readonly property color accentInk: "#ffffff"
    readonly property color accentSoft: Qt.rgba(0.31, 0.55, 1, 0.16)

    readonly property color good: "#3fbf72"
    readonly property color bad: "#e5484d"
    readonly property color note: "#e8b339"
    readonly property color warn: "#e8b339"

    readonly property string mono: Qt.platform.os === "windows" ? "Cascadia Mono, Consolas" : "DejaVu Sans Mono"
    readonly property int radius: 6
    readonly property int radiusLg: 10
    readonly property int fontSmall: 11
    readonly property int fontBody: 13
    readonly property int fontTitle: 15

    function kindColor(k) { return k === 1 ? good : (k === 2 ? bad : note) }
    function kindName(k) { return k === 1 ? "Good take" : (k === 2 ? "Mistake" : "Note") }
}
