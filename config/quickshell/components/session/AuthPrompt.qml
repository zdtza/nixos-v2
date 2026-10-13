import QtQuick
import QtQuick.Effects
import "../primitives"
import "../../services"
import "../.."

// Polkit's authentication prompt: the desktop dimmed behind a fixed-size bordered field. A wrong
// password turns the characters red with the lock screen's glow and shakes the field, then clears it.
Item {
    id: root

    property bool inputEnabled: true
    property bool responseVisible: false
    property alias text: passwordInput.text
    readonly property alias input: passwordInput

    // Set by fail() for the red hold; the field clears when it ends.
    property bool failing: false

    signal accepted()

    function fail(): void {
        failing = true;
        shake.restart();
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
            passwordInput.text = "";
            passwordInput.forceActiveFocus();
        }
    }

    // Polkit's window is transparent; this alone dims the desktop behind it.
    Rectangle {
        anchors.fill: parent
        color: Utils.alpha(Theme.base00, Utils.scrimOpacity)
    }

    // Clicking the scrim must not leave the user typing into nothing: every press bounces focus back to the field.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: passwordInput.forceActiveFocus()
    }

    ShellShadow {
        anchors.fill: field
        transform: Translate { x: shakeShift.x }
    }

    Rectangle {
        id: field

        anchors.centerIn: parent
        width: Math.min(360, parent.width - 48)
        height: 48
        radius: PanelService.rounding
        color: Utils.alpha(Theme.base01, 0.95)
        border.width: 2
        // Typing does not change the outline; only failure and checking do.
        border.color: root.failing ? Theme.base08
            : (root.inputEnabled ? Theme.base04 : Utils.alpha(Theme.base05, 0.4))
        transform: Translate { id: shakeShift }

        Behavior on border.color { ColorAnimation { duration: 120 } }

        TextInput {
            id: passwordInput
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            horizontalAlignment: TextInput.AlignHCenter
            verticalAlignment: TextInput.AlignVCenter
            readOnly: !root.inputEnabled || root.failing
            echoMode: root.responseVisible ? TextInput.Normal : TextInput.Password
            passwordCharacter: "●"
            // The caret stays visible so the prompt clearly reads as ready for keyboard input.
            cursorVisible: !root.failing
            color: root.failing ? Theme.base08 : Theme.textPrimary
            selectionColor: Theme.base02
            selectedTextColor: Theme.textPrimary
            font.family: Theme.monospace
            font.pixelSize: Utils.scaledFont(22)
            font.letterSpacing: 2
            Accessible.name: "Password"
            Accessible.passwordEdit: !root.responseVisible
            onAccepted: root.accepted()
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

            // The lock screen's failure glow, on the characters.
            layer.enabled: root.failing
            layer.effect: MultiEffect {
                shadowEnabled: true
                // MultiEffect takes glow strength from shadowOpacity; shadowColor's alpha is not applied.
                shadowColor: Theme.base08
                shadowOpacity: 0.7
                shadowBlur: 1
                blurMax: 12
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
            }
        }
    }

    // The lock screen's shake (PasswordDots.qml), on the whole field.
    SequentialAnimation {
        id: shake
        NumberAnimation { target: shakeShift; property: "x"; to: -28; duration: 34; easing.type: Easing.OutQuad }
        NumberAnimation { target: shakeShift; property: "x"; to: 28; duration: 52; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shakeShift; property: "x"; to: -22; duration: 49; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shakeShift; property: "x"; to: 16; duration: 45; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shakeShift; property: "x"; to: -10; duration: 41; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shakeShift; property: "x"; to: 4; duration: 38; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shakeShift; property: "x"; to: 0; duration: 34; easing.type: Easing.OutQuad }
    }
}
