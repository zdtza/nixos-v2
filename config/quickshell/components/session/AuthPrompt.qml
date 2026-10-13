import QtQuick
import "../primitives"
import "../../services"
import "../.."

// Polkit's authentication prompt: the desktop dimmed with base01 and a bordered field showing the lock
// screen's password dots, with a centred caret while it is empty. Non-secret prompts (responseVisible) echo
// the typed text instead of dots.
Item {
    id: root

    property bool inputEnabled: true
    property bool responseVisible: false
    property alias text: passwordInput.text
    readonly property alias input: passwordInput

    // Set by fail() for the red-dot hold; the field is already cleared underneath.
    property bool failing: false
    // Dot count at submit, so the red dots match what was typed whenever Polkit clears the field.
    property int submittedDots: 0

    // Submitted and waiting on PAM shows as checking; Polkit closes the prompt on success.
    readonly property string phase: failing ? "fail"
        : (!inputEnabled && text.length > 0 ? "checking"
            : (text.length > 0 ? "typing" : "idle"))

    signal accepted()

    // Wrong password: red dots and the shake, then back to an empty field.
    function fail(): void {
        failing = true;
        passwordInput.text = "";
        dots.fail();
        failClear.restart();
    }

    LockMotion {
        id: lockMotion
    }

    Timer {
        id: failClear
        interval: lockMotion.failClear
        onTriggered: {
            root.failing = false;
            passwordInput.forceActiveFocus();
        }
    }

    // Polkit's window is transparent; this alone dims the desktop behind it.
    Rectangle {
        anchors.fill: parent
        color: Theme.base01
        opacity: Utils.scrimOpacity
    }

    ShellShadow {
        anchors.fill: field
    }

    Rectangle {
        id: field

        anchors.centerIn: parent
        // Grows past the default width if the dots need it.
        width: Math.min(Math.max(360, dots.implicitWidth + 48), parent.width - 48)
        height: 48
        radius: PanelService.rounding
        color: Utils.alpha(Theme.base01, 0.95)
        border.width: 2
        // Typing does not change the outline; only failure and checking do.
        border.color: root.failing ? Theme.base08
            : (root.inputEnabled ? Theme.base04 : Utils.alpha(Theme.base05, 0.4))

        Behavior on border.color { ColorAnimation { duration: 120 } }

        PasswordDots {
            id: dots
            anchors.centerIn: parent
            visible: !root.responseVisible
            timing: lockMotion
            dotColor: Theme.base05
            failColor: Theme.base08
            successColor: Theme.base07
            phase: root.phase
            dotCount: root.failing ? root.submittedDots : root.text.length
        }

        ShellText {
            anchors.centerIn: parent
            visible: root.responseVisible
            text: passwordInput.text
            size: 22
        }

        // Centred blinking caret while the field is empty and ready, so it reads as waiting for input.
        Rectangle {
            id: caret

            anchors.centerIn: parent
            width: 2
            height: 20
            color: Theme.base05
            visible: root.phase === "idle" && root.inputEnabled

            SequentialAnimation on opacity {
                running: caret.visible
                loops: Animation.Infinite
                onRunningChanged: if (!running) caret.opacity = 1
                PropertyAction { value: 1 }
                PauseAnimation { duration: 530 }
                PropertyAction { value: 0 }
                PauseAnimation { duration: 530 }
            }
        }
    }

    // Invisible but focused; fills the screen so any click lands on it.
    TextInput {
        id: passwordInput
        anchors.fill: parent
        opacity: 0
        echoMode: TextInput.Password
        cursorVisible: false
        readOnly: !root.inputEnabled || root.failing
        Accessible.name: "Password"
        Accessible.role: Accessible.EditableText
        Accessible.passwordEdit: !root.responseVisible
        onAccepted: {
            root.submittedDots = text.length;
            root.accepted();
        }
        // Anything that steals focus while the prompt is up gives it back.
        onActiveFocusChanged: if (!activeFocus && enabled)
            Qt.callLater(() => passwordInput.forceActiveFocus())
        Keys.onPressed: event => {
            if (event.key === Qt.Key_C && event.modifiers === Qt.ControlModifier) {
                if (!readOnly)
                    passwordInput.text = "";
                event.accepted = true;
            }
        }
    }

    // Hide the pointer, as the lock screen does; no buttons accepted, so clicks still reach the field.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.BlankCursor
    }
}
