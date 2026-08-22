import QtQuick
import Quickshell
import Stylix

// Shared anchored card used by bar panel popups.
PopupWindow {
    id: root

    required property Item anchorItem
    required property var anchorWindow
    property color borderColor: Theme.border
    property real contentMargins: 20
    property real contentHorizontalMargins: contentMargins
    property real contentVerticalMargins: contentMargins
    property real contentSpacing: 14
    default property alias panelChildren: contentColumn.data
    readonly property alias panelContent: contentColumn

    signal closeRequested()

    color: "transparent"

    Shortcut {
        enabled: root.visible
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        onActivated: root.closeRequested()
    }

    anchor {
        id: popupAnchor
        window: root.anchorWindow
        edges: Edges.Top | Edges.Left
        gravity: Edges.Bottom | Edges.Right
        adjustment: PopupAdjustment.Slide
        rect.width: 1
        rect.height: 1

        onAnchoring: {
            const window = root.anchorWindow;
            if (!window)
                return;
            let point = window.contentItem.mapFromItem(root.anchorItem, root.anchorItem.width / 2 - root.implicitWidth / 2, root.anchorItem.height + PanelService.barGap);
            point.x = Math.max(5, Math.min(point.x, window.width - root.implicitWidth - 7));
            popupAnchor.rect.x = Math.round(point.x);
            popupAnchor.rect.y = Math.round(point.y);
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.background
        border.width: 2
        border.color: root.borderColor
        radius: 0

        Column {
            id: contentColumn
            anchors {
                fill: parent
                leftMargin: root.contentHorizontalMargins
                rightMargin: root.contentHorizontalMargins
                topMargin: root.contentVerticalMargins
                bottomMargin: root.contentVerticalMargins
            }
            spacing: root.contentSpacing
        }
    }
}
