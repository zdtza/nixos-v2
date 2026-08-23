// Countdown control and duration-entry panel.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Stylix

Item {
    id: root

    readonly property bool opened: PanelService.activePanel === root
    readonly property bool requiresKeyboardFocus: true
    property bool inputReady: false
    property bool updatingInput: false

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
        setInputText(TimerService.formatDuration(TimerService.running
            ? TimerService.remainingSeconds : TimerService.lastDurationSeconds));
    }

    function startTimer(): void {
        const seconds = parseDuration(durationInput.text);
        if (TimerService.start(seconds))
            setInputText(TimerService.formatDuration(seconds));
    }

    function toggleSavedTimer(): void {
        if (TimerService.running) {
            TimerService.cancel();
            resetInput();
        } else {
            TimerService.start(TimerService.lastDurationSeconds);
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
                root.toggleSavedTimer();
            else
                PanelService.toggle(root);
        }
    }

    Timer {
        interval: 250
        running: root.opened && TimerService.running
        repeat: true
        onTriggered: root.setInputText(TimerService.formatDuration(
            TimerService.remainingSeconds))
    }

    Connections {
        target: TimerService
        function onElapsed(): void {
            if (root.opened)
                root.setInputText("00:00");
        }
    }

    HyprlandFocusGrab {
        active: root.opened
        windows: [panel, root.QsWindow.window]
        onCleared: PanelService.close(root)
    }

    PanelPopup {
        id: panel

        anchorItem: root
        anchorWindow: root.QsWindow.window
        visible: root.opened
        onCloseRequested: PanelService.close(root)
        onVisibleChanged: {
            if (!visible)
                return;
            root.resetInput();
            if (!TimerService.running)
                Qt.callLater(() => {
                    durationInput.forceActiveFocus();
                    durationInput.selectAll();
                });
        }

        borderColor: Theme.border
        contentSpacing: 14
        implicitWidth: 420
        implicitHeight: panelContent.implicitHeight + contentMargins * 2

        PanelHero {
            width: parent.width
            icon: "󱎫"
            title: "Timer"
            status: TimerService.running ? "TICK TOCK" : "READY"
            trailingWidth: 44
            trailingHeight: 24

            Rectangle {
                anchors.fill: parent
                readonly property bool canStart: root.parseDuration(durationInput.text) > 0
                readonly property bool controlEnabled: TimerService.running || canStart
                color: TimerService.running
                    ? Theme.foreground
                    : Qt.rgba(Theme.foreground.r, Theme.foreground.g,
                        Theme.foreground.b, 0.18)
                border.width: 1
                border.color: Qt.rgba(Theme.foreground.r, Theme.foreground.g,
                    Theme.foreground.b, 0.4)
                opacity: controlEnabled ? 1 : 0.5
                Behavior on color { ColorAnimation { duration: 120 } }

                Rectangle {
                    width: 18
                    height: 18
                    y: 3
                    x: TimerService.running ? parent.width - width - 3 : 3
                    color: TimerService.running ? Theme.background : Theme.foreground
                    Behavior on x {
                        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: parent.controlEnabled
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (TimerService.running) {
                            TimerService.cancel();
                            root.resetInput();
                            durationInput.forceActiveFocus();
                            durationInput.selectAll();
                        } else {
                            root.startTimer();
                        }
                    }
                }
            }
        }

        PanelSeparator {}

        PanelSectionHeader {
            title: "DURATION"
            detail: TimerService.running ? "REMAINING" : "MM : SS"
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
                enabled: !TimerService.running
                focus: true
                activeFocusOnPress: true
                selectByMouse: true
                inputMask: "00:00"
                text: "00:00"
                onTextChanged: {
                    if (root.inputReady && !root.updatingInput
                            && !TimerService.running && root.durationParts(text))
                        TimerService.rememberDuration(root.parseDuration(text));
                }
                color: enabled ? Theme.foreground : Theme.muted
                selectionColor: Theme.surface
                selectedTextColor: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 36
                font.weight: Font.Medium
                font.letterSpacing: 3

                Keys.onReturnPressed: root.startTimer()
                Keys.onEnterPressed: root.startTimer()
                Keys.onEscapePressed: PanelService.close(root)
            }
        }

    }
}
