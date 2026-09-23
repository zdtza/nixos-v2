import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"

// Shared chrome for floating panels opened from the bar.
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

    // Concrete surfaces define their horizontal anchors. Keep cards one Hyprland
    // outer gap clear of the configured bar edge.
    margins.top: PanelService.barAtTop
        ? PanelService.panelBarInset + PanelService.panelGap : 0
    margins.bottom: PanelService.barAtTop
        ? 0 : PanelService.panelBarInset + PanelService.panelGap

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
            top: PanelService.barAtTop ? parent.top : undefined
            bottom: PanelService.barAtTop ? undefined : parent.bottom
            left: parent.left
            right: parent.right
        }
        height: root.open ? root.height : 0
        clip: true

        Rectangle {
            anchors.fill: parent
            enabled: root.open
            color: Theme.base01
            radius: 0
            border.width: PanelService.chromeBorderWidth
            border.color: PanelService.chromeBorderColor

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
