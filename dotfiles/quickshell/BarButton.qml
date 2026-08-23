import QtQuick
import Stylix

// Fixed-width bar button shared by panel-backed status controls.
Item {
    id: root

    required property var panel
    property string text: ""
    property color textColor: Theme.foreground
    property int acceptedButtons: Qt.LeftButton
    property bool showPanelIndicator: true

    readonly property bool panelOpen: ServicePanel.activePanel === root.panel

    signal clicked(var mouse)
    signal wheeled(var wheel)

    implicitWidth: 26
    implicitHeight: 26
    clip: true

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -1
        text: root.text
        color: root.textColor
        font.family: Theme.fontFamily
        font.pixelSize: 14
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: 16
        height: 2
        radius: ServicePanel.rounding
        visible: root.showPanelIndicator && (root.panelOpen || mouseArea.containsMouse)
        color: Theme.accent
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: root.acceptedButtons
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => root.clicked(mouse)
        onWheel: wheel => root.wheeled(wheel)
    }
}
