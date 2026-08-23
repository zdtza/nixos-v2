import QtQuick
import Stylix

// Segmented-control cell: one option in a row of equal-width buttons (power
// profiles, display scales, color-temperature presets). Distinguishes hover,
// the keyboard cursor, the currently active value, and press, independent of
// each other. Content (label, icon, ...) is declared as normal children.
Rectangle {
    id: root

    property bool active: false
    property bool keyboardFocused: false
    property bool enabled: true
    readonly property alias hovered: mouseArea.containsMouse
    readonly property bool highlighted: keyboardFocused || hovered

    signal activated()

    implicitHeight: 32
    radius: ServicePanel.rounding
    color: mouseArea.pressed
        ? Util.alpha(Theme.foreground, 0.22)
        : root.active
            ? Util.alpha(Theme.foreground, 0.18)
            : root.highlighted
                ? Util.alpha(Theme.foreground, 0.08)
                : Util.alpha(Theme.foreground, 0.04)
    border.width: 1
    border.color: root.active
        ? Theme.muted
        : root.highlighted ? Util.alpha(Theme.foreground, 0.25) : Util.alpha(Theme.foreground, 0.4)
    Behavior on color { ColorAnimation { duration: 120 } }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.activated()
    }
}
