import QtQuick

// One of Slate's line icons, rendered sharp at any size (see src/icons.cpp).
Image {
    property string name: "file"
    property color color: "#e8eaed"
    property int size: 18
    width: size; height: size
    sourceSize: Qt.size(size, size)
    source: name ? "image://icon/" + name + "?" + color : ""
    smooth: true
    cache: true
    asynchronous: false
}
