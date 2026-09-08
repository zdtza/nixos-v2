import QtQuick
import "../services"

// One collapsible cell of the quick-toggle tray. Collapses to nothing behind
// the clock when `shown` is false; its content stays instantiated and is
// revealed by animating the clipped width, so nothing is rebuilt on hover.
Item {
    id: root

    property bool shown: false
    default property alias content: holder.data

    width: implicitWidth
    implicitWidth: shown ? 28 : 0
    implicitHeight: 26
    clip: true

    Behavior on implicitWidth {
        NumberAnimation { duration: PanelService.slideDuration; easing.type: Easing.OutCubic }
    }

    // Full-size and right-anchored, so a collapsing cell slides out behind
    // its neighbour instead of squashing its own content.
    Item {
        id: holder
        anchors.right: parent.right
        width: 28
        height: 26
    }
}
