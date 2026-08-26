import QtQuick
import Stylix
import "../services"
import ".."

// Selectable option cell used by power profiles and display scales. Selection
// and hover use the same visual language as device, network, and monitor rows.
// Content (label, icon, ...) is declared as normal children.
Rectangle {
    id: root

    property bool active: false
    property bool keyboardFocused: false
    property bool enabled: true
    readonly property alias hovered: mouseArea.containsMouse
    // Hover and keyboard share one focus cursor. `active` remains separate: it
    // marks value currently applied by system after cursor moves elsewhere.
    readonly property bool highlighted: keyboardFocused

    signal activated()

    implicitHeight: 32
    radius: ServicePanel.rounding
    opacity: root.enabled ? 1 : 0.5
    color: mouseArea.pressed
        ? Utils.alpha(Theme.foreground, 0.22)
        : root.highlighted
            ? Utils.alpha(Theme.foreground, 0.12)
            : root.active
                ? Utils.alpha(Theme.foreground, 0.08)
                : "transparent"
    border.width: root.active || root.highlighted ? 1 : 0
    border.color: Utils.alpha(Theme.foreground,
        root.highlighted ? 0.35 : 0.25)
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
