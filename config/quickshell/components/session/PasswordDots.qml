import QtQuick
import QtQuick.Effects

// Password feedback shared by the lock screen (LockVisual) and Polkit (AuthPrompt): one dot per character
// that pops in, a glow that builds while checking, red dots with a shake on failure, and a full glow on
// success. No text, ever.
Item {
    id: root

    property color dotColor
    property color failColor
    property color successColor
    property LockMotion timing: LockMotion {}

    // idle | typing | checking | fail | success; anything else hides the dots.
    property string phase: "idle"
    property int dotCount: 0

    readonly property bool designed: timing.designed
    readonly property int maxDots: 24
    readonly property bool dotsShown: phase === "typing" || phase === "checking"
        || phase === "fail" || phase === "success"

    // Restarted explicitly so repeated fails replay even though no property changes.
    function fail(): void {
        shake.restart();
    }

    function resetShake(): void {
        shake.stop();
        shakeShift.x = 0;
    }

    implicitWidth: Math.max(dots.implicitWidth, 32)
    implicitHeight: 24
    transform: Translate { id: shakeShift }

    Row {
        id: dots

        // Checking pulse, shared by every dot so they breathe in sync.
        property real pulse: 1
        // 0 while typing → 1 at success. Checking ramps it over a typical PAM check, so the dots are
        // already most of the way to the success glow when a right password comes back.
        property real charge: 0
        readonly property bool failing: root.phase === "fail"
        readonly property color tint: failing ? root.failColor
            : Qt.rgba(root.dotColor.r + (root.successColor.r - root.dotColor.r) * charge,
                root.dotColor.g + (root.successColor.g - root.dotColor.g) * charge,
                root.dotColor.b + (root.successColor.b - root.dotColor.b) * charge, 1)

        anchors.centerIn: parent
        spacing: 9

        // A copy created already in success starts fully charged, matching the lock it replaces.
        Component.onCompleted: if (root.phase === "success")
            charge = 1

        Connections {
            target: root

            function onPhaseChanged(): void {
                if (root.phase === "checking") {
                    chargeUp.restart();
                } else if (root.phase === "success") {
                    chargeUp.stop();
                    chargeFinish.restart();
                } else if (root.phase !== "fail") {
                    // Fail keeps the current glow strength, recoloured red, until the field clears.
                    chargeUp.stop();
                    chargeFinish.stop();
                    dots.charge = 0;
                }
            }
        }

        NumberAnimation {
            id: chargeUp
            target: dots
            property: "charge"
            from: 0
            to: 1
            // Builds quickly after Enter, so a wrong password (~1.9 s to fail) turns red from a full glow.
            duration: 800
            easing.type: Easing.InOutSine
        }

        NumberAnimation {
            id: chargeFinish
            target: dots
            property: "charge"
            to: 1
            // Spans the whole success hold, so the dots glow up smoothly and arrive at full charge
            // just as the unlock copy (which starts fully charged) takes over.
            duration: root.timing.successHold
            easing.type: Easing.InOutSine
        }

        SequentialAnimation on pulse {
            running: root.phase === "checking" && root.designed
            loops: Animation.Infinite
            NumberAnimation { to: 0; duration: 450; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: 450; easing.type: Easing.InOutSine }
        }

        // Always layered while dots show, so the glow fades in from zero instead of switching on.
        layer.enabled: root.dotsShown
        layer.effect: MultiEffect {
            shadowEnabled: true
            // MultiEffect takes glow strength from shadowOpacity; shadowColor's alpha is not applied.
            shadowColor: dots.failing ? root.failColor : root.successColor
            shadowOpacity: dots.failing ? 0.7 : 0.85 * dots.charge
            shadowBlur: 1
            blurMax: dots.failing ? 12 : 12 + 4 * dots.charge
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }

        // A fixed pool of dots, shown left to right; rebuilding them per keystroke would replay every pop.
        Repeater {
            model: root.maxDots

            Rectangle {
                id: dot

                required property int index
                readonly property bool shown: root.dotsShown
                    && index < Math.min(root.dotCount, root.maxDots)
                property real pop: 1

                visible: shown
                onShownChanged: if (shown)
                    popIn.restart()

                width: 12
                height: 12
                radius: 6
                color: dots.tint
                opacity: root.phase === "checking" && root.designed ? 0.45 + 0.55 * dots.pulse : 1
                scale: pop * (1 + 0.15 * dots.charge)
                    * (root.phase === "checking" && root.designed ? 0.8 + 0.3 * dots.pulse : 1)

                // Only the jump to red animates; the charge ramp is already smooth.
                Behavior on color {
                    enabled: root.designed && dots.failing
                    ColorAnimation { duration: 200 }
                }

                NumberAnimation {
                    id: popIn
                    target: dot
                    property: "pop"
                    from: 0
                    to: 1
                    duration: root.designed ? 220 : 80
                    easing.type: root.designed ? Easing.OutBack : Easing.OutCubic
                }
            }
        }
    }

    // Wrong password: a wide, decaying shake of the dots, the same in both motion modes (~290 ms).
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
