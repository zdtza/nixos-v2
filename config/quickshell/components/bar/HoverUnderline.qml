import QtQuick
import "../../services"

// Short bar along a bar control's bottom edge, faded in while hovered or open.
Rectangle {
    property bool shown: false

    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    width: Math.min(16, parent.width)
    height: 2
    radius: PanelService.rounding
    visible: opacity > 0
    opacity: shown ? 1 : 0
    color: Theme.base05

    Behavior on opacity { NumberAnimation { duration: 120 } }
}
