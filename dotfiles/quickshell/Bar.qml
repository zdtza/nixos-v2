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

    anchors {
        top: true
        left: true
        right: true
    }

    // --- left ---
    RowLayout {
        anchors {
            leftMargin: 6
            left: parent.left
            verticalCenter: parent.verticalCenter
        }

        Workspaces {
            screen: bar.screen
        }
    }

    // --- center ---
    Clock {
        anchors.centerIn: parent
    }

    // --- right ---
    RowLayout {
        anchors {
            right: parent.right
            rightMargin: 12
            verticalCenter: parent.verticalCenter
        }
        spacing: 24

        Tray {}

        Network {}

        Bluetooth {}
        
        Volume {}

        Display {}

        Battery {}
    }
}
