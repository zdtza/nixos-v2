import QtQuick
import "../../services"

// One collapsible cell of the quick-toggle tray.
Item {
    id: root

    property bool shown: false
    // The slot carries its own bar spacing so collapsed slots leave no gap;
    // it sits on the side away from the clock.
    property bool gapBefore: true
    default property alias content: holder.data

    width: implicitWidth
    implicitWidth: shown ? PanelService.barIconWidth + PanelService.barSpacing : 0
    implicitHeight: PanelService.barItemHeight
    clip: true

    Behavior on implicitWidth {
        NumberAnimation { duration: PanelService.slideDuration; easing.type: Easing.OutCubic }
    }

    // Full-size and anchored on the clock side, so a collapsing cell slides out behind its neighbour instead of squashing its own content.
    Item {
        id: holder
        anchors.right: root.gapBefore ? parent.right : undefined
        anchors.left: root.gapBefore ? undefined : parent.left
        width: PanelService.barIconWidth
        height: PanelService.barItemHeight
    }
}
