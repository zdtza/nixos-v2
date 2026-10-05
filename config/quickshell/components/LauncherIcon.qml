import QtQuick
import "../services"

// NixOS logo, swapped for a ring spinner while LauncherService reports an app launching.
Item {
    id: root

    property real size: 16
    property color color: Theme.textPrimary
    readonly property real ringSize: Math.round(size * 0.875)

    // Sized by the logo so swapping to the spinner never shifts the layout.
    implicitWidth: logo.implicitWidth
    implicitHeight: logo.implicitHeight

    ShellText {
        id: logo
        anchors.centerIn: parent
        visible: !LauncherService.launching
        text: "\uf313"
        color: root.color
        size: root.size
    }

    Spinner {
        anchors.centerIn: parent
        size: root.ringSize
        visible: LauncherService.launching
    }
}
