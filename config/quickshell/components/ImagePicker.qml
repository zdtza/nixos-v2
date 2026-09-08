pragma ComponentBehavior: Bound

// Skewed-slice image carousel, a port of omarchy's image-picker plugin
// (~/omarchy/shell/plugins/image-picker/ImagePicker.qml) -- same geometry,
// same parallelogram slices, same dim/border treatment, with omarchy's
// Color/Style tokens mapped onto this shell's Theme palette:
//   Color.imagePicker.scrim -> base00 @ 0.5
//   dimColor                -> base00
//
// omarchy's slice borders and caption are dropped: the selected slice already
// reads as selected by being the only undimmed, full-size one.
//
// Purely presentational: the caller supplies `items` and decides what
// accepting one means, so the same component backs the wallpaper picker
// today and a theme picker later -- each instance just gets its own
// `ipcTarget`.
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "../services"
import ".."

Scope {
    id: root

    // [{ image: url, value: var }]. `value` is handed back
    // untouched through accepted(), so callers can carry whatever key they
    // need (a file path, a theme name) without this component knowing.
    property var items: []
    // Entry already in use; the carousel opens on it.
    property var selectedValue: null
    // Enables `qs ipc call <ipcTarget> toggle|open|close|isOpen`.
    property string ipcTarget: ""
    property bool open: false

    // Geometry, verbatim from omarchy's ImagePicker.
    property int expandedWidth: 768
    property int expandedHeight: 475
    property int sliceWidth: 108
    property int sliceHeight: 432
    property int sliceSpacing: -30
    property int skewOffset: 28
    readonly property int bottomChromeHeight: 30

    property color dimColor: Theme.base00
    property color scrim: Utils.alpha(Theme.base00, 0.5)

    property int selectedIndex: 0

    signal accepted(item: var)

    // Monitor the picker was opened on, resolved to a screen below. Same
    // idiom as Launcher.qml: overlays open where the keyboard focus is.
    property string openedMonitorName: ""

    function indexOfSelected(): int {
        for (let index = 0; index < root.items.length; index++) {
            if (root.items[index].value === root.selectedValue)
                return index;
        }
        return 0;
    }

    function currentItem(): var {
        return root.items[root.selectedIndex] ?? null;
    }

    // Wraps around at both ends, like omarchy's selectAdjacent.
    function selectAdjacent(direction: int): void {
        const count = root.items.length;
        if (count === 0)
            return;
        root.selectedIndex = (root.selectedIndex + direction + count) % count;
    }

    function show(): void {
        root.openedMonitorName = String(Hyprland.focusedMonitor?.name ?? "");
        PanelService.closeActive();
        root.selectedIndex = root.indexOfSelected();
        root.open = true;
    }

    function toggle(): void {
        if (root.open)
            root.open = false;
        else
            root.show();
    }

    function acceptItem(item: var): void {
        if (!item)
            return;
        root.open = false;
        root.accepted(item);
    }

    IpcHandler {
        target: root.ipcTarget
        enabled: root.ipcTarget !== ""

        function toggle(): void { root.toggle(); }
        function open(): void { root.show(); }
        function close(): void { root.open = false; }
        function isOpen(): bool { return root.open; }
    }

    PanelWindow {
        id: window

        screen: Utils.screenForMonitor(root.openedMonitorName)
        // Unlike the launcher this isn't opened dozens of times a session, so
        // it unmaps when closed rather than staying mapped behind a zero-sized
        // input region.
        visible: root.open
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.namespace: "quickshell:image-picker"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open
            ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Rectangle {
            anchors.fill: parent
            color: root.scrim
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.open = false
        }

        Item {
            id: card

            anchors.centerIn: parent
            // 13 slices' worth of run-off on each side of the expanded
            // preview is what omarchy budgets for the fanned-out neighbours.
            width: Math.min(parent.width - 80,
                root.expandedWidth + 13 * (root.sliceWidth + root.sliceSpacing) + 40)
            height: root.expandedHeight + 30 + root.bottomChromeHeight

            // Clicks on the carousel itself must not fall through to the
            // close-on-click scrim behind it.
            MouseArea {
                anchors.fill: parent
                onPressed: mouse => mouse.accepted = true
            }

            Item {
                id: carousel

                anchors {
                    top: parent.top
                    topMargin: 30
                    bottom: parent.bottom
                    bottomMargin: root.bottomChromeHeight
                    horizontalCenter: parent.horizontalCenter
                }
                width: root.expandedWidth + 13 * (root.sliceWidth + root.sliceSpacing)
                clip: false
                focus: true

                readonly property real itemStep: root.sliceWidth + root.sliceSpacing
                readonly property real previewX: (width - root.expandedWidth) / 2

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        root.open = false;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.acceptItem(root.currentItem());
                    } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab
                            || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                        root.selectAdjacent(-1);
                    } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
                        root.selectAdjacent(1);
                    } else {
                        return;
                    }
                    event.accepted = true;
                }

                Repeater {
                    model: root.items

                    delegate: Item {
                        id: slice

                        required property var modelData
                        required property int index

                        readonly property int relativeIndex: index - root.selectedIndex
                        readonly property bool selected: index === root.selectedIndex
                        // Only the neighbours that can actually reach the
                        // screen are built/decoded; once one has been near, its
                        // texture is kept so scrolling past doesn't re-decode.
                        readonly property bool nearby: Math.abs(relativeIndex) <= 16
                        property bool sourceActivated: nearby
                        onNearbyChanged: if (nearby) sourceActivated = true

                        visible: nearby
                        x: selected ? carousel.previewX
                            : (relativeIndex < 0
                                ? carousel.previewX + relativeIndex * carousel.itemStep
                                : carousel.previewX + root.expandedWidth + root.sliceSpacing
                                    + (relativeIndex - 1) * carousel.itemStep)
                        y: selected ? 0 : (root.expandedHeight - root.sliceHeight) / 2
                        width: selected ? root.expandedWidth : root.sliceWidth
                        height: selected ? root.expandedHeight : root.sliceHeight
                        z: selected ? 100 : 50 - Math.min(Math.abs(relativeIndex), 40)

                        // Parallelogram corners: the top edge leans one way by
                        // skewOffset, the bottom edge the other.
                        readonly property real skewAbs: Math.abs(root.skewOffset)
                        readonly property real topLeft: root.skewOffset >= 0 ? skewAbs : 0
                        readonly property real topRight: root.skewOffset >= 0 ? width : width - skewAbs
                        readonly property real bottomRight: root.skewOffset >= 0 ? width - skewAbs : width
                        readonly property real bottomLeft: root.skewOffset >= 0 ? 0 : skewAbs

                        Item {
                            id: maskShape

                            anchors.fill: parent
                            visible: false
                            layer.enabled: true

                            Shape {
                                anchors.fill: parent
                                antialiasing: true
                                preferredRendererType: Shape.CurveRenderer

                                ShapePath {
                                    fillColor: "white"
                                    strokeColor: "transparent"
                                    startX: slice.topLeft
                                    startY: 0

                                    PathLine { x: slice.topRight; y: 0 }
                                    PathLine { x: slice.bottomRight; y: slice.height }
                                    PathLine { x: slice.bottomLeft; y: slice.height }
                                    PathLine { x: slice.topLeft; y: 0 }
                                }
                            }
                        }

                        Item {
                            anchors.fill: parent
                            layer.enabled: true
                            layer.smooth: true
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: maskShape
                                maskThresholdMin: 0.3
                                maskSpreadAtMin: 0.3
                            }

                            Image {
                                anchors.fill: parent
                                source: slice.sourceActivated ? (slice.modelData.image ?? "") : ""
                                fillMode: Image.PreserveAspectCrop
                                // Wallpapers are 6-8K JPEGs (25 MPix, ~100 MB
                                // of RGBA each) but the biggest slice is
                                // expandedWidth x expandedHeight -- without a
                                // sourceSize every one is decoded at full size
                                // on open, which is the whole open delay.
                                // Qt scales during JPEG decode, so this is
                                // cheap; 2x the slice for HiDPI headroom.
                                sourceSize.height: root.expandedHeight * 2
                                asynchronous: false
                                cache: true
                                smooth: true
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: Utils.alpha(root.dimColor, slice.selected ? 0 : 0.42)
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (slice.selected)
                                    root.acceptItem(slice.modelData);
                                else
                                    root.selectedIndex = slice.index;
                            }
                        }
                    }
                }
            }

        }

        Connections {
            target: root

            function onOpenChanged(): void {
                if (!root.open)
                    return;
                // The layer surface is only mapped once `visible` propagates,
                // so focus has to wait a turn or it lands on nothing.
                Qt.callLater(() => carousel.forceActiveFocus());
            }
        }
    }
}
