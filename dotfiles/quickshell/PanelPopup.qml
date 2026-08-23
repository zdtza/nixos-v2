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
    // Moving/reordered bar controls can otherwise drag an open popup with them.
    property bool freezePositionWhileVisible: false
    property bool useNativeFocus: false
    property bool positionFrozen: false
    property point frozenPosition: Qt.point(0, 0)
    default property alias panelChildren: contentColumn.data
    readonly property alias panelContent: contentColumn

    signal closeRequested()
    signal backgroundClicked()

    color: "transparent"
    grabFocus: useNativeFocus

    onVisibleChanged: {
        if (visible)
            return;
        positionFrozen = false;
        closeRequested();
    }

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
            let point;
            if (root.freezePositionWhileVisible && root.positionFrozen) {
                point = root.frozenPosition;
            } else {
                point = window.contentItem.mapFromItem(root.anchorItem,
                    root.anchorItem.width / 2 - root.implicitWidth / 2,
                    root.anchorItem.height + ServicePanel.barGap + ServicePanel.gapTopOffset);
                point.x = Math.max(ServicePanel.barGap + ServicePanel.gapLeftOffset,
                    Math.min(point.x, window.width - root.implicitWidth
                        - ServicePanel.barGap - ServicePanel.gapRightOffset));
                point.x = Math.round(point.x);
                point.y = Math.round(point.y);
                if (root.freezePositionWhileVisible) {
                    root.frozenPosition = point;
                    root.positionFrozen = true;
                }
            }
            popupAnchor.rect.x = point.x;
            popupAnchor.rect.y = point.y;
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.background
        border.width: 1
        border.color: root.borderColor
        radius: ServicePanel.rounding

        MouseArea {
            anchors.fill: parent
            onClicked: root.backgroundClicked()
        }

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
