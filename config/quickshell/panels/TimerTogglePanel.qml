pragma ComponentBehavior: Bound

// Multiple countdown controls and duration-entry panel.
import QtQuick
import Quickshell
import "../components"
import "../services"
import ".."

Item {
    id: root

    property bool showButton: true
    readonly property bool opened: PanelService.activePanel === root
    readonly property bool requiresKeyboardFocus: true
    readonly property int timerRowHeight: 48
    readonly property int timerRowSpacing: 8
    property bool inputReady: false
    property bool updatingInput: false
    property alias keyboardInputText: durationInput.text
    property int selectedTimerIndex: -1

    // Mounted in the bar window while this panel is active.
    readonly property Component keyboardProxy: durationProxy

    implicitWidth: showButton ? 28 : 0
    implicitHeight: PanelService.barItemHeight

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

    Component {
        id: durationProxy

        TextInput {
            focus: true
            inputMask: "00:00"
            text: root.keyboardInputText

            onTextEdited: root.setInputText(text)
            onActiveFocusChanged: if (activeFocus)
                selectAll()

            Keys.onReturnPressed: root.startTimer()
            Keys.onEnterPressed: root.startTimer()
            Keys.onDownPressed: root.selectTimer(1)
            Keys.onUpPressed: root.selectTimer(-1)
            Keys.onDeletePressed: if (root.selectedTimerIndex >= 0)
                root.removeSelectedTimer()
            Keys.onEscapePressed: PanelService.close(root)
        }
    }

    Button {
        anchors.centerIn: parent
        visible: root.showButton
        panel: root
        text: "󱎫"
        textColor: TimerService.running ? Theme.textPrimary : Theme.textSecondary
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.startSavedTimer();
            else
                PanelService.toggle(root);
        }
    }


    Drawer {
        id: panel

        anchorItem: root
        onOpenChanged: {
            if (!open)
                return;
            root.resetInput();
            Qt.callLater(() => {
                durationInput.forceActiveFocus();
                durationInput.selectAll();
            });
        }

        // Derive popup size from stable controls and timer count.
        readonly property real panelChromeHeight: contentTopMargin
            + contentBottomMargin + timerHero.implicitHeight + durationHeader.implicitHeight
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

        Hero {
            id: timerHero
            width: parent.width
            icon: "󱎫"
            title: "Timer"
            status: TimerService.timers.length > 0
                ? TimerService.timers.length + (TimerService.timers.length === 1
                    ? " TIMER RUNNING" : " TIMERS RUNNING")
                : "READY"
            RowActionButton {
                implicitWidth: 32
                icon: "󰐕"
                iconSize: 14
                enabled: root.parseDuration(durationInput.text) > 0
                onClicked: root.startTimer()
            }
        }

        Separator {}

        SectionHeader {
            id: durationHeader
            title: "DURATION"
            detail: "MM : SS"
        }

        Rectangle {
            width: parent.width
            height: 74
            radius: PanelService.rounding
            color: Theme.base01
            border.width: 1
            border.color: durationInput.activeFocus ? Theme.base04
                : Utils.alpha(Theme.base05, 0.3)


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
                color: Theme.textPrimary
                selectionColor: Theme.base02
                selectedTextColor: Theme.textPrimary
                font.family: Theme.monospace
                font.pixelSize: Utils.scaledFont(36)
                font.weight: Font.Medium
                font.letterSpacing: 3

                Keys.onReturnPressed: root.startTimer()
                Keys.onEnterPressed: root.startTimer()
                Keys.onDownPressed: root.focusTimerList()
                Keys.onEscapePressed: PanelService.close(root)
            }
        }

        Separator {}

        SectionHeader {
            id: timersHeader
            title: "CURRENT TIMERS"
            detail: TimerService.timers.length === 0 ? "NONE"
                : String(TimerService.timers.length)
        }

        Item {
            width: parent.width
            height: panel.timerViewportHeight
            clip: true

            ShellText {
                anchors.fill: parent
                visible: TimerService.timers.length === 0
                text: "No running timers"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: Theme.textSecondary
                size: 12
            }

            ScrollArea {
                id: timerList
                anchors.fill: parent
                visible: TimerService.timers.length > 0
                contentHeight: timerColumn.implicitHeight
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

                        ListRow {
                            id: timerRow
                            required property var modelData
                            required property int index

                            height: root.timerRowHeight
                            icon: "󱎫"
                            title: TimerService.formatDuration(Math.max(0,
                                Math.ceil((modelData.deadlineMs - TimerService.nowMs) / 1000)))
                            titleSize: 24
                            titleWeight: Font.Medium
                            titleLeftMargin: 12
                            clickable: false
                            selected: index === root.selectedTimerIndex
                            onHoverSelected: root.selectedTimerIndex = index

                            RowActionButton {
                                icon: "󰆴"
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
