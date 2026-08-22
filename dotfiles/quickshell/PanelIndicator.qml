import QtQuick
import Stylix

// Shared bar icon with consistent sizing and pointer behavior.
Item {
    id: root

    property string text: ""
    property color textColor: Theme.foreground
    property int acceptedButtons: Qt.LeftButton

    signal clicked(var mouse)
    signal wheeled(var wheel)

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.textColor
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: root.acceptedButtons
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => root.clicked(mouse)
        onWheel: wheel => root.wheeled(wheel)
    }
}
