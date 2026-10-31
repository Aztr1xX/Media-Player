import QtQuick
import QtQuick.Controls
import Slate

// Dark context / drop-down menu.
Menu {
    id: m
    padding: 5
    implicitWidth: 260
    delegate: SMenuItem {}
    background: Rectangle { implicitWidth: 220; color: "#1d1f23"; radius: 8; border.color: Theme.lineStrong }
}
