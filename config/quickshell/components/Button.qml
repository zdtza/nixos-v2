import QtQuick
import Stylix
import "../services"
import ".."

// Fixed-width bar button shared by panel-backed status controls.
Item {
    id: root

    required property var panel
    property string text: ""
    property color textColor: Theme.base05
    property int acceptedButtons: Qt.LeftButton
    property bool showPanelIndicator: true

    readonly property bool panelOpen: PanelService.activePanel === root.panel

    signal clicked(var mouse)
    signal wheeled(var wheel)

    implicitWidth: 22
    implicitHeight: 26
    clip: true

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -1
        text: root.text
        color: root.textColor
        font.family: Theme.monospace
        font.pixelSize: Utils.scaledFont(14)
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: 16
        height: 2
        radius: PanelService.rounding
        visible: opacity > 0
        opacity: root.showPanelIndicator && (root.panelOpen || mouseArea.containsMouse) ? 1 : 0
        color: Theme.base0D

        Behavior on opacity { NumberAnimation { duration: 120 } }
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
