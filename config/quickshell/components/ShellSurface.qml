import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"

// Shared chrome for every panel that hangs off the bar's underside.
PanelWindow {
    id: root

    required property Item anchorItem
    required property var anchorWindow
    property bool open: false
    property bool closeOnEscape: true
    // Flush against the screen's right edge.
    property bool edgeAligned: false
    property real contentMargins: 20
    property real contentHorizontalMargins: contentMargins
    property real contentTopMargin: contentMargins
    property real contentBottomMargin: contentMargins
    property real contentSpacing: 14
    readonly property real cornerSize: PanelService.barVisible
        ? PanelService.shellRounding : 0
    default property alias panelChildren: contentColumn.data
    readonly property alias panelContent: contentColumn

    signal closeRequested()
    signal backgroundClicked()

    screen: anchorWindow ? anchorWindow.screen : null
    visible: !!anchorWindow
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.open
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Concrete surfaces define their own anchors.
    margins.top: PanelService.barVisible ? PanelService.barHeight : 0

    mask: Region {
        width: surfaceClip.height > 0 ? root.width : 0
        height: surfaceClip.height
    }

    Item {
        width: 1
        height: 1
        focus: root.open
    }

    PanelShortcut {
        enabled: root.open && root.closeOnEscape
        sequences: ["Escape"]
        onActivated: root.closeRequested()
    }

    // Arms hover-select once the pointer genuinely moves, as opposed to a panel merely appearing underneath a still cursor.
    HoverHandler {
        enabled: root.open && !PanelService.hoverSelectReady
        acceptedDevices: PointerDevice.AllDevices
        onPointChanged: PanelService.armHoverSelect(point.position.x, point.position.y)
    }

    Item {
        id: surfaceClip
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: root.open ? root.height : 0
        clip: true

        // Behavior so a growing height while open.
        Behavior on height {
            enabled: root.open
            NumberAnimation { duration: PanelService.slideDuration; easing.type: Easing.OutCubic }
        }

        ShellCorner {
            width: root.cornerSize
            height: Math.min(width, surfaceClip.height)
        }

        ShellCorner {
            mirrored: true
            visible: !root.edgeAligned
            x: parent.width - width
            width: root.cornerSize
            height: Math.min(width, surfaceClip.height)
        }

        Rectangle {
            x: root.cornerSize
            width: root.edgeAligned
                ? parent.width - x : parent.width - root.cornerSize * 2
            height: surfaceClip.height
            enabled: root.open
            color: Theme.base01
            radius: PanelService.shellRounding
            topLeftRadius: 0
            topRightRadius: 0
            bottomRightRadius: root.edgeAligned ? 0 : PanelService.shellRounding

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
