pragma ComponentBehavior: Bound

// Multiple countdown controls and duration-entry panel.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Stylix

Item {
    id: root

    readonly property bool opened: ServicePanel.activePanel === root
    readonly property bool requiresKeyboardFocus: true
    readonly property int timerRowHeight: 48
    readonly property int timerRowSpacing: 8
    property bool inputReady: false
    property bool updatingInput: false
    property alias keyboardInputText: durationInput.text
    property int selectedTimerIndex: -1

    implicitWidth: 28
    implicitHeight: 26

    function durationParts(value: string): var {
        const match = /^(\d{2}):(\d{2})$/.exec(String(value));
        if (!match)
            return null;

        const minutes = Number(match[1]);
        const seconds = Number(match[2]);
        if (minutes > 99 || seconds > 59)
            return null;
        return { minutes, seconds };
    }

    function parseDuration(value: string): int {
        const parts = durationParts(value);
        return parts ? parts.minutes * 60 + parts.seconds : 0;
    }

    function setInputText(value: string): void {
        updatingInput = true;
        durationInput.text = value;
        updatingInput = false;
    }

    function resetInput(): void {
        setInputText(ServiceTimer.formatDuration(ServiceTimer.lastDurationSeconds));
    }

    function startTimer(): void {
        const seconds = parseDuration(durationInput.text);
        if (ServiceTimer.start(seconds)) {
            setInputText(ServiceTimer.formatDuration(seconds));
            durationInput.forceActiveFocus();
            durationInput.selectAll();
        }
    }

    function startSavedTimer(): void {
        ServiceTimer.start(ServiceTimer.lastDurationSeconds);
    }

    function selectTimer(offset: int): void {
        if (ServiceTimer.timers.length === 0) {
            selectedTimerIndex = -1;
            return;
        }
        if (selectedTimerIndex < 0) {
            selectedTimerIndex = offset > 0 ? 0 : ServiceTimer.timers.length - 1;
        } else if (selectedTimerIndex === 0 && offset < 0) {
            selectedTimerIndex = -1;
            durationInput.forceActiveFocus();
            durationInput.selectAll();
        } else {
            selectedTimerIndex = Math.max(0,
                Math.min(ServiceTimer.timers.length - 1, selectedTimerIndex + offset));
        }
    }

    function removeSelectedTimer(): void {
        const timer = ServiceTimer.timers[selectedTimerIndex];
        if (timer)
            ServiceTimer.removeTimer(timer.id);
    }

    function focusTimerList(): void {
        selectTimer(1);
        if (selectedTimerIndex >= 0)
            timerList.forceActiveFocus();
    }

    onOpenedChanged: if (!opened)
        selectedTimerIndex = -1
    onSelectedTimerIndexChanged: if (selectedTimerIndex >= ServiceTimer.timers.length)
        selectedTimerIndex = ServiceTimer.timers.length - 1

    Connections {
        target: ServiceTimer
        function onTimersChanged(): void {
            if (root.selectedTimerIndex >= ServiceTimer.timers.length)
                root.selectedTimerIndex = ServiceTimer.timers.length - 1;
            if (root.opened && root.selectedTimerIndex < 0) {
                durationInput.forceActiveFocus();
                durationInput.selectAll();
            }
        }
    }

    Component.onCompleted: inputReady = true

    BarButton {
        anchors.centerIn: parent
        panel: root
        text: "󱎫"
        textColor: ServiceTimer.running ? Theme.foreground : Theme.muted
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.startSavedTimer();
            else
                ServicePanel.toggle(root);
        }
    }

    HyprlandFocusGrab {
        active: root.opened
        windows: [panel, root.QsWindow.window]
        onCleared: ServicePanel.close(root)
    }

    PanelPopup {
        id: panel

        anchorItem: root
        anchorWindow: root.QsWindow.window
        visible: root.opened
        freezePositionWhileVisible: true
        onCloseRequested: ServicePanel.close(root)
        onVisibleChanged: {
            if (!visible)
                return;
            root.resetInput();
            Qt.callLater(() => {
                durationInput.forceActiveFocus();
                durationInput.selectAll();
            });
        }

        borderColor: Theme.border
        contentSpacing: 14
        readonly property real maximumHeight: Math.max(320,
            (root.QsWindow.window && root.QsWindow.window.screen
                ? root.QsWindow.window.screen.height : 800) - 55)
        // Derive popup size from stable controls and timer count. Avoid
        // Column.implicitHeight while repeater delegates are changing.
        readonly property real panelChromeHeight: contentTopMargin
            + contentBottomMargin + timerHero.implicitHeight + durationHeader.implicitHeight
            + timersHeader.implicitHeight + 76 + contentSpacing * 6
        readonly property real desiredTimerHeight: ServiceTimer.timers.length > 0
            ? ServiceTimer.timers.length * root.timerRowHeight
                + Math.max(0, ServiceTimer.timers.length - 1) * root.timerRowSpacing
            : 52
        readonly property real timerViewportHeight: Math.min(272,
            Math.max(52, maximumHeight - panelChromeHeight), desiredTimerHeight)

        implicitWidth: 420
        implicitHeight: Math.min(maximumHeight,
            panelChromeHeight + timerViewportHeight)

        PanelHero {
            id: timerHero
            width: parent.width
            icon: "󱎫"
            title: "Timer"
            status: ServiceTimer.timers.length > 0
                ? ServiceTimer.timers.length + (ServiceTimer.timers.length === 1
                    ? " TIMER RUNNING" : " TIMERS RUNNING")
                : "READY"
            trailingWidth: 32
            trailingHeight: 28

            Rectangle {
                anchors.fill: parent
                readonly property bool canStart: root.parseDuration(durationInput.text) > 0
                radius: ServicePanel.rounding
                color: addMouse.containsMouse
                    ? Util.alpha(Theme.foreground, 0.12)
                    : "transparent"
                border.width: 1
                border.color: Util.alpha(Theme.foreground, 0.3)
                opacity: canStart ? 1 : 0.5
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰐕"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Util.scaledFont(14)
                }

                MouseArea {
                    id: addMouse
                    anchors.fill: parent
                    enabled: parent.canStart
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.startTimer()
                }
            }
        }

        PanelSeparator {}

        PanelSectionHeader {
            id: durationHeader
            title: "DURATION"
            detail: "MM : SS"
        }

        Rectangle {
            width: parent.width
            height: 74
            radius: ServicePanel.rounding
            color: Theme.dark_background
            border.width: 1
            border.color: durationInput.activeFocus ? Theme.muted
                : Util.alpha(Theme.foreground, 0.3)

            TextInput {
                id: durationInput

                anchors.fill: parent
                horizontalAlignment: TextInput.AlignHCenter
                verticalAlignment: TextInput.AlignVCenter
                focus: true
                activeFocusOnPress: true
                selectByMouse: true
                inputMask: "00:00"
                text: "00:00"
                onTextChanged: {
                    if (root.inputReady && !root.updatingInput && root.durationParts(text))
                        ServiceTimer.rememberDuration(root.parseDuration(text));
                }
                color: Theme.foreground
                selectionColor: Theme.surface
                selectedTextColor: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Util.scaledFont(36)
                font.weight: Font.Medium
                font.letterSpacing: 3

                Keys.onReturnPressed: root.startTimer()
                Keys.onEnterPressed: root.startTimer()
                Keys.onDownPressed: root.focusTimerList()
                Keys.onEscapePressed: ServicePanel.close(root)
            }
        }

        PanelSeparator {}

        PanelSectionHeader {
            id: timersHeader
            title: "CURRENT TIMERS"
            detail: ServiceTimer.timers.length === 0 ? "NONE"
                : String(ServiceTimer.timers.length)
        }

        Item {
            width: parent.width
            height: panel.timerViewportHeight
            clip: true

            Text {
                anchors.fill: parent
                visible: ServiceTimer.timers.length === 0
                text: "No running timers"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Util.scaledFont(12)
            }

            Flickable {
                id: timerList
                anchors.fill: parent
                visible: ServiceTimer.timers.length > 0
                contentHeight: timerColumn.implicitHeight
                clip: true
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick
                activeFocusOnTab: true

                Keys.onUpPressed: root.selectTimer(-1)
                Keys.onDownPressed: root.selectTimer(1)
                Keys.onDeletePressed: root.removeSelectedTimer()
                Keys.onEscapePressed: ServicePanel.close(root)

                Column {
                    id: timerColumn
                    width: timerList.width
                    spacing: root.timerRowSpacing

                    Repeater {
                        model: ServiceTimer.timers

                        Rectangle {
                            id: timerRow
                            required property var modelData
                            required property int index

                            width: timerColumn.width
                            height: root.timerRowHeight
                            radius: ServicePanel.rounding
                            color: timerRow.index === root.selectedTimerIndex || rowHover.hovered
                                ? Util.alpha(Theme.foreground, 0.08)
                                : "transparent"
                            border.width: timerRow.index === root.selectedTimerIndex
                                || rowHover.hovered ? 1 : 0
                            border.color: Util.alpha(Theme.foreground, 0.25)
                            Behavior on color { ColorAnimation { duration: 120 } }

                            HoverHandler { id: rowHover }

                            Text {
                                id: timerIcon
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: "󱎫"
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: Util.scaledFont(16)
                            }

                            Text {
                                anchors.left: timerIcon.right
                                anchors.leftMargin: 12
                                anchors.right: deleteButton.visible
                                    ? deleteButton.left : parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: ServiceTimer.formatDuration(Math.max(0,
                                    Math.ceil((timerRow.modelData.deadlineMs
                                        - ServiceTimer.nowMs) / 1000)))
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: Util.scaledFont(24)
                                font.weight: Font.Medium
                            }

                            PanelRowActionButton {
                                id: deleteButton
                                z: 2
                                visible: timerRow.index === root.selectedTimerIndex || rowHover.hovered
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                icon: "󰆴"
                                onClicked: {
                                    root.selectedTimerIndex = timerRow.index;
                                    ServiceTimer.removeTimer(timerRow.modelData.id);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
