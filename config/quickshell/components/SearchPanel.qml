pragma ComponentBehavior: Bound

// The surface both the launcher and the keybind sheet are: a card on a click-to-dismiss scrim, one search field over one list.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../services"
import ".."

Scope {
    id: root

    property bool open: false
    property string layerNamespace: ""
    property string placeholder: ""
    property int frameWidth: 400
    property int rowHeight: 48
    property int rowSpacing: 2
    property int contentPadding: 10
    property int searchRowHeight: 40
    property int listGap: 8
    property var model: []
    property Component delegate: null
    // The card stays collapsed to the search bar until the caller has something worth showing under it.
    property bool expanded: false
    readonly property int searchBarHeight: root.contentPadding * 2
        + root.searchRowHeight
    // Whole rows only.
    property int maxRows: Math.max(1, Math.floor(
        (window.height * 0.44 - root.searchBarHeight - root.listGap + root.rowSpacing)
            / (root.rowHeight + root.rowSpacing)))

    property alias query: search.text
    property alias currentIndex: list.currentIndex
    // Hover-select stays disarmed until the pointer genuinely moves after opening.
    property bool hoverSelectReady: false

    // Empty/loading overlays are declared by the caller as list children.
    default property alias listData: list.data

    signal accepted

    property string openedMonitorName: ""

    function show(): void {
        root.openedMonitorName = String(Hyprland.focusedMonitor?.name ?? "");
        PanelService.closeActive();
        root.open = true;
    }

    function toggle(): void {
        if (root.open)
            root.open = false;
        else
            root.show();
    }

    function moveSelection(offset: int): void {
        if (list.count === 0) {
            list.currentIndex = -1;
            return;
        }
        list.currentIndex = Math.max(0, Math.min(list.count - 1,
            (list.currentIndex < 0 ? 0 : list.currentIndex) + offset));
        list.positionViewAtIndex(list.currentIndex, ListView.Contain);
    }

    onOpenChanged: {
        root.hoverSelectReady = false;
        window.armPosition = null;
        // Reset immediately on close rather than on open, so the frame is already collapsed before it is shown.
        search.text = "";
        list.currentIndex = list.count > 0 ? 0 : -1;
        if (!root.open)
            return;
        search.forceActiveFocus();
        list.positionViewAtBeginning();
    }

    Connections {
        target: Hyprland

        function onFocusedMonitorChanged(): void {
            if (root.open && String(Hyprland.focusedMonitor?.name ?? "") !== root.openedMonitorName)
                root.open = false;
        }
    }

    PanelWindow {
        id: window

        screen: Utils.screenForMonitor(root.openedMonitorName)

        // Keep the layer surface mapped.
        visible: true
        color: "transparent"
        mask: Region {
            width: root.open ? window.width : 0
            height: root.open ? window.height : 0
        }
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: root.layerNamespace
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open
            ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // Cursor position seen the first time it is reported after opening, compared against later ones to tell real.
        property var armPosition: null

        Rectangle {
            anchors.fill: parent
            color: Utils.alpha(Theme.base00, Utils.scrimOpacity)
            opacity: root.open ? 1 : 0
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.open
            onClicked: root.open = false
        }

        // A HoverHandler on the window sees every pointer move regardless of which child is topmost, unlike a MouseArea.
        HoverHandler {
            enabled: root.open && !root.hoverSelectReady
            acceptedDevices: PointerDevice.AllDevices
            onPointChanged: {
                if (window.armPosition === null)
                    window.armPosition = Qt.point(point.position.x, point.position.y);
                else if (point.position.x !== window.armPosition.x
                        || point.position.y !== window.armPosition.y)
                    root.hoverSelectReady = true;
            }
        }

        Rectangle {
            id: frame

            // Pinned to the top edge it would have at full height, not centred.
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round((parent.height - frame.maxHeight) / 2)
            width: Math.min(root.frameWidth, parent.width - 32)

            readonly property int maxHeight: root.searchBarHeight + root.listGap
                + root.maxRows * root.rowHeight + (root.maxRows - 1) * root.rowSpacing
            // At least one row tall while expanded, so an overlay message fits.
            readonly property int listHeight: Math.max(root.rowHeight,
                list.count * root.rowHeight + (list.count - 1) * root.rowSpacing)

            height: root.expanded
                ? Math.min(frame.maxHeight, root.searchBarHeight + root.listGap + frame.listHeight)
                : root.searchBarHeight
            enabled: root.open

            clip: true
            radius: 0
            color: Theme.base01
            border.width: PanelService.panelBorderWidth
            border.color: Theme.base04
            opacity: root.open ? 1 : 0

            MouseArea {
                anchors.fill: parent
                onPressed: mouse => mouse.accepted = true
            }

            ColumnLayout {
                anchors {
                    fill: parent
                    leftMargin: root.contentPadding
                    rightMargin: root.contentPadding
                    topMargin: root.contentPadding
                    bottomMargin: root.contentPadding
                }
                opacity: root.open ? 1 : 0
                spacing: root.listGap

                // The prompt is deliberately not a separate rounded field; spacing alone separates it from the result list.
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.searchRowHeight

                    ShellText {
                        id: searchIcon
                        anchors {
                            left: parent.left
                            leftMargin: 10
                            verticalCenter: parent.verticalCenter
                        }
                        text: "󰍉"
                        color: Theme.base04
                        size: 14
                    }

                    TextInput {
                        id: search

                        anchors {
                            left: searchIcon.right
                            right: parent.right
                            leftMargin: 10
                            rightMargin: 10
                            verticalCenter: parent.verticalCenter
                        }
                        height: 30
                        verticalAlignment: TextInput.AlignVCenter
                        focus: true
                        selectByMouse: true
                        clip: true
                        color: Theme.base05
                        selectionColor: Theme.base02
                        selectedTextColor: Theme.base05
                        font.family: Theme.monospace
                        font.pixelSize: Utils.scaledFont(14)

                        cursorDelegate: Rectangle {
                            width: 1
                            color: Theme.base05
                        }

                        ShellText {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: search.text === ""
                            text: root.placeholder
                            color: Theme.base04
                            size: 14
                        }

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_C && event.modifiers === Qt.ControlModifier) {
                                search.text = "";
                                event.accepted = true;
                            }
                        }
                        Keys.onEscapePressed: root.open = false
                        Keys.onDownPressed: root.moveSelection(1)
                        Keys.onUpPressed: root.moveSelection(-1)
                        Keys.onReturnPressed: root.accepted()
                        Keys.onEnterPressed: root.accepted()
                    }
                }

                ListView {
                    id: list

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: root.rowSpacing
                    model: root.model
                    delegate: root.delegate
                    boundsBehavior: Flickable.StopAtBounds

                    // Every query change starts over at the top match.
                    onModelChanged: list.currentIndex = list.count > 0 ? 0 : -1
                }
            }
        }
    }
}
