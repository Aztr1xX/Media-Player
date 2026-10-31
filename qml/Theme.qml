pragma Singleton
import QtQuick

QtObject {
    readonly property color bg: "#0f1114"
    readonly property color panel: "#171a1f"
    readonly property color raise: "#20242b"
    readonly property color line: "#2b3038"
    readonly property color ink: "#e8eaee"
    readonly property color muted: "#8b93a1"
    readonly property color accent: "#ff9a3c"
    readonly property color accentInk: "#1a1006"
    readonly property color cool: "#5eb3ff"
    readonly property color good: "#4fd18b"
    readonly property color bad: "#ff5f6d"
    readonly property string mono: Qt.platform.os === "windows" ? "Consolas" : "DejaVu Sans Mono"
    readonly property int radius: 6

    function kindColor(k) { return k === 1 ? good : (k === 2 ? bad : cool) }
    function kindName(k) { return k === 1 ? "Good slate" : (k === 2 ? "Mistake" : "Note") }
}
