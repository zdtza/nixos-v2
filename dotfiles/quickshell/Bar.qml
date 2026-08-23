// Top bar layer-shell panel. Three anchored groups: left, right, and a clock
// pinned to the true center of the bar (independent of the side widths).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Stylix
import Quickshell.Wayland

PanelWindow {
    id: bar

    required property var modelData

    screen: modelData
    color: Theme.dark_background
    implicitHeight: 30

    WlrLayershell.namespace: "quickshell:bar"
    WlrLayershell.keyboardFocus: PanelService.activePanel?.requiresKeyboardFocus
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors {
        top: true
        left: true
        right: true
    }

    // Popup focus grabs include bar so controls remain directly clickable.
    // This background target dismisses active popup when unused bar area is hit.
    MouseArea {
        anchors.fill: parent
        onClicked: PanelService.closeActive()
    }

    // --- left ---
    RowLayout {
        anchors {
            leftMargin: 6
            left: parent.left
            verticalCenter: parent.verticalCenter
        }

        Power {}

        Workspaces {
            screen: bar.screen
        }
    }

    // --- center ---
    Clock {
        id: clock
        anchors.centerIn: parent
    }

    QuickToggles {
        anchors {
            right: clock.left
            verticalCenter: clock.verticalCenter
        }
    }


    // --- right ---
    RowLayout {
        anchors {
            right: parent.right
            rightMargin: 12
            verticalCenter: parent.verticalCenter
        }

        Tray {}

        Volume {}

        Bluetooth {}

        Display {}

        Network {}

        Battery {}
    }
}
