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
    // Tallest a scrolling panel may grow on its screen.
    readonly property real maximumHeight: Math.max(320, (screen?.height ?? 800) - 55)

    signal closeRequested()
    signal backgroundClicked()

    screen: anchorWindow ? anchorWindow.screen : null
    visible: !!anchorWindow
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    implicitHeight: contentColumn.implicitHeight + contentTopMargin + contentBottomMargin

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.open
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Concrete surfaces (Drawer) define their anchors and margins.

    mask: Region {
        width: surfaceClip.height > 0 ? root.width : 0
        height: surfaceClip.height
    }

    // Panel keyboard proxy, mounted here as well as in the bar window: Hyprland
    // hands keyboard focus to whichever of the two is under the pointer
    // (follow_mouse), so typing must work from either.
    readonly property Component keyboardProxy: root.anchorItem?.keyboardProxy ?? null

    Item {
        width: 1
        height: 1
        focus: root.open && !root.keyboardProxy
    }

    Loader {
        x: -10
        width: 1
        height: 1
        opacity: 0
        active: root.open && !!root.keyboardProxy
        focus: active
        sourceComponent: root.keyboardProxy
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
