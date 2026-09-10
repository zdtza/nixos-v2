import QtQuick
import "../services"
import ".."

// Selectable option cell used by power profiles and display scales. Only the
// cursor (hover or keyboard) is drawn -- the applied value is deliberately not
// marked, since a panel is reopened with the cursor already on it. Same visual
// language as device, network, and monitor rows. Content (label, icon, ...) is
// declared as normal children.
Rectangle {
    id: root

    property bool keyboardFocused: false
    property bool enabled: true
    readonly property alias hovered: mouseArea.containsMouse
    // Hover and keyboard share one focus cursor.
    readonly property bool highlighted: keyboardFocused

    signal activated()

    implicitHeight: 32
    radius: PanelService.rounding
    opacity: root.enabled ? 1 : 0.5
    color: mouseArea.pressed
        ? Utils.alpha(Theme.base05, 0.22)
        : root.highlighted
            ? Utils.alpha(Theme.base05, 0.12)
            : "transparent"
    border.width: root.highlighted ? 1 : 0
    border.color: Utils.alpha(Theme.base05, 0.35)

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.activated()
    }
}
