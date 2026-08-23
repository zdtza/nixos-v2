pragma ComponentBehavior: Bound

// Multiple countdown controls and duration-entry panel.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Stylix

Item {
    id: root

    readonly property bool opened: PanelService.activePanel === root
    readonly property bool requiresKeyboardFocus: false
    readonly property int timerRowHeight: 48
    readonly property int timerRowSpacing: 8
    property bool inputReady: false
    property bool updatingInput: false
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
        setInputText(TimerService.formatDuration(TimerService.lastDurationSeconds));
    }

    function startTimer(): void {
        const seconds = parseDuration(durationInput.text);
        if (TimerService.start(seconds)) {
            setInputText(TimerService.formatDuration(seconds));
            durationInput.forceActiveFocus();
            durationInput.selectAll();
        }
    }

    function startSavedTimer(): void {
        TimerService.start(TimerService.lastDurationSeconds);
    }

    function selectTimer(offset: int): void {
        if (TimerService.timers.length === 0) {
            selectedTimerIndex = -1;
            return;
        }
        if (selectedTimerIndex < 0) {
            selectedTimerIndex = offset > 0 ? 0 : TimerService.timers.length - 1;
        } else if (selectedTimerIndex === 0 && offset < 0) {
            selectedTimerIndex = -1;
            durationInput.forceActiveFocus();
            durationInput.selectAll();
        } else {
            selectedTimerIndex = Math.max(0,
                Math.min(TimerService.timers.length - 1, selectedTimerIndex + offset));
        }
    }

    function removeSelectedTimer(): void {
        const timer = TimerService.timers[selectedTimerIndex];
        if (timer)
            TimerService.removeTimer(timer.id);
    }

    function focusTimerList(): void {
        selectTimer(1);
        if (selectedTimerIndex >= 0)
            timerList.forceActiveFocus();
    }

    onOpenedChanged: if (!opened)
        selectedTimerIndex = -1
    onSelectedTimerIndexChanged: if (selectedTimerIndex >= TimerService.timers.length)
        selectedTimerIndex = TimerService.timers.length - 1

    Connections {
        target: TimerService
        function onTimersChanged(): void {
            if (root.selectedTimerIndex >= TimerService.timers.length)
                root.selectedTimerIndex = TimerService.timers.length - 1;
            if (root.opened && root.selectedTimerIndex < 0) {
                durationInput.forceActiveFocus();
                durationInput.selectAll();
            }
        }
    }

    Component.onCompleted: inputReady = true

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -1
        text: "󱎫"
        color: TimerService.running ? Theme.foreground : Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 14
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.startSavedTimer();
            else
                PanelService.toggle(root);
        }
    }

    PanelPopup {
        id: panel

        anchorItem: root
        anchorWindow: root.QsWindow.window
        visible: root.opened
        useNativeFocus: true
        freezePositionWhileVisible: true
        onCloseRequested: PanelService.close(root)
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
        readonly property real panelChromeHeight: contentMargins * 2
            + timerHero.implicitHeight + durationHeader.implicitHeight
            + timersHeader.implicitHeight + 76 + contentSpacing * 6
        readonly property real desiredTimerHeight: TimerService.timers.length > 0
            ? TimerService.timers.length * root.timerRowHeight
                + Math.max(0, TimerService.timers.length - 1) * root.timerRowSpacing
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
            status: TimerService.timers.length > 0
                ? TimerService.timers.length + (TimerService.timers.length === 1
                    ? " TIMER RUNNING" : " TIMERS RUNNING")
                : "READY"
            trailingWidth: 32
            trailingHeight: 28

            Rectangle {
                anchors.fill: parent
                readonly property bool canStart: root.parseDuration(durationInput.text) > 0
                color: addMouse.containsMouse
                    ? Qt.rgba(Theme.foreground.r, Theme.foreground.g,
                        Theme.foreground.b, 0.12)
                    : "transparent"
                border.width: 1
                border.color: Qt.rgba(Theme.foreground.r, Theme.foreground.g,
                    Theme.foreground.b, 0.3)
                opacity: canStart ? 1 : 0.5
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰐕"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
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
            color: Theme.dark_background
            border.width: 1
            border.color: durationInput.activeFocus ? Theme.muted
                : Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.3)

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
                        TimerService.rememberDuration(root.parseDuration(text));
                }
                color: Theme.foreground
                selectionColor: Theme.surface
                selectedTextColor: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 36
                font.weight: Font.Medium
                font.letterSpacing: 3

                Keys.onReturnPressed: root.startTimer()
                Keys.onEnterPressed: root.startTimer()
                Keys.onDownPressed: root.focusTimerList()
                Keys.onEscapePressed: PanelService.close(root)
            }
        }

        PanelSeparator {}

        PanelSectionHeader {
            id: timersHeader
            title: "CURRENT TIMERS"
            detail: TimerService.timers.length === 0 ? "NONE"
                : String(TimerService.timers.length)
        }

        Item {
            width: parent.width
            height: panel.timerViewportHeight
            clip: true

            Text {
                anchors.fill: parent
                visible: TimerService.timers.length === 0
                text: "No running timers"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }

            Flickable {
                id: timerList
                anchors.fill: parent
                visible: TimerService.timers.length > 0
                contentHeight: timerColumn.implicitHeight
                clip: true
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick
                activeFocusOnTab: true

                Keys.onUpPressed: root.selectTimer(-1)
                Keys.onDownPressed: root.selectTimer(1)
                Keys.onDeletePressed: root.removeSelectedTimer()
                Keys.onEscapePressed: PanelService.close(root)

                Column {
                    id: timerColumn
                    width: timerList.width
                    spacing: root.timerRowSpacing

                    Repeater {
                        model: TimerService.timers

                        Rectangle {
                            id: timerRow
                            required property var modelData
                            required property int index

                            width: timerColumn.width
                            height: root.timerRowHeight
                            color: timerRow.index === root.selectedTimerIndex || rowHover.hovered
                                ? Qt.rgba(Theme.foreground.r, Theme.foreground.g,
                                    Theme.foreground.b, 0.08)
                                : "transparent"
                            border.width: timerRow.index === root.selectedTimerIndex
                                || rowHover.hovered ? 1 : 0
                            border.color: Qt.rgba(Theme.foreground.r,
                                Theme.foreground.g, Theme.foreground.b, 0.25)
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
                                font.pixelSize: 16
                            }

                            Text {
                                anchors.left: timerIcon.right
                                anchors.leftMargin: 12
                                anchors.right: deleteButton.visible
                                    ? deleteButton.left : parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: TimerService.formatDuration(Math.max(0,
                                    Math.ceil((timerRow.modelData.deadlineMs
                                        - TimerService.nowMs) / 1000)))
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 24
                                font.weight: Font.Medium
                            }

                            Rectangle {
                                id: deleteButton
                                z: 2
                                visible: timerRow.index === root.selectedTimerIndex || rowHover.hovered
                                width: 28
                                height: 28
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                color: deleteMouse.containsMouse
                                    ? Qt.rgba(Theme.foreground.r,
                                        Theme.foreground.g, Theme.foreground.b, 0.12)
                                    : "transparent"
                                border.width: 1
                                border.color: Qt.rgba(Theme.foreground.r,
                                    Theme.foreground.g, Theme.foreground.b, 0.3)

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰆴"
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                }

                                MouseArea {
                                    id: deleteMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.selectedTimerIndex = timerRow.index;
                                        TimerService.removeTimer(timerRow.modelData.id);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
