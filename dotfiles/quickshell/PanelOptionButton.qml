import QtQuick
import Stylix

// Selectable option cell used by power profiles and display scales. Selection
// and hover use the same visual language as device, network, and monitor rows.
// Content (label, icon, ...) is declared as normal children.
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
    opacity: root.enabled ? 1 : 0.5
    color: mouseArea.pressed
        ? Util.alpha(Theme.foreground, 0.22)
        : root.active || root.highlighted
            ? Util.alpha(Theme.foreground, 0.08)
            : "transparent"
    border.width: root.active || root.highlighted ? 1 : 0
    border.color: Util.alpha(Theme.foreground, 0.25)
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
