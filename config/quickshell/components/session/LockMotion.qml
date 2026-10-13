import QtQuick

// The lock screen's motion switch and the timings LockScreen and LockVisual both need.
QtObject {
    // "designed" plays the mockup timings; "fast" matches the shell's near-instant motion.
    property string motion: "fast"

    readonly property bool designed: motion === "designed"
    // Wrong password: how long the red feedback holds before the field clears.
    // At least as long as the ~290 ms shake, so the red dots finish shaking before they clear.
    readonly property int failClear: designed ? 700 : 450
    // Right password: how long the dots take to glow up fully before the unlock transition.
    readonly property int successHold: designed ? 350 : 300
    // Login lock: fade in from the black Hyprland starts on.
    readonly property int loginFade: 250
}
