import QtQuick
import Quickshell
import Quickshell.Wayland
import Stylix
import "../services"

// Screen-edge drawer used by right-side system panels.
PanelWindow {
    id: root

    required property Item anchorItem
    required property var anchorWindow
    property bool open: false
    property bool closeOnEscape: true
    property real contentMargins: 20
    property real contentHorizontalMargins: contentMargins
    property real contentTopMargin: contentMargins
    property real contentBottomMargin: contentMargins
    property real contentSpacing: 14
    readonly property real cornerSize: ServicePanel.shellRounding
    default property alias panelChildren: contentColumn.data
    readonly property alias panelContent: contentColumn

    signal closeRequested()
    signal backgroundClicked()

    screen: anchorWindow ? anchorWindow.screen : null
    visible: !!anchorWindow
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.namespace: "quickshell:panel-drawer"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.open
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors {
        top: true
        right: true
    }
    margins.top: ServicePanel.barHeight

    mask: Region {
        width: drawerClip.height > 0 ? root.width : 0
        height: drawerClip.height
    }

    Item {
        width: 1
        height: 1
        focus: root.open
    }

    Shortcut {
        enabled: root.open && root.closeOnEscape
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        onActivated: root.closeRequested()
    }

    Item {
        id: drawerClip
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: root.open ? root.height : 0
        clip: true

        // Behavior (not a one-shot animation to a fixed target) so a growing
        // height while open -- e.g. network scan results hydrating in --
        // retargets smoothly instead of snapping once the old target is hit.
        Behavior on height {
            enabled: root.open
            NumberAnimation { duration: ServicePanel.slideDuration; easing.type: Easing.OutCubic }
        }

        Canvas {
            width: root.cornerSize
            height: Math.min(width, drawerClip.height)

            onPaint: {
                const context = getContext("2d");
                context.clearRect(0, 0, width, width);
                context.fillStyle = Theme.dark_background;
                context.beginPath();
                context.moveTo(0, 0);
                context.lineTo(width, 0);
                context.lineTo(width, width);
                context.arc(0, width, width, 0, -Math.PI / 2, true);
                context.fill();
            }
        }

        Rectangle {
            x: root.cornerSize
            width: parent.width - x
            height: drawerClip.height
            enabled: root.open
            color: Theme.dark_background
            radius: ServicePanel.shellRounding
            topLeftRadius: 0
            topRightRadius: 0
            bottomRightRadius: 0

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
                    topMargin: root.contentTopMargin
                    bottomMargin: root.contentBottomMargin
                }
                opacity: root.open ? 1 : 0
                spacing: root.contentSpacing
            }
        }
    }
}
