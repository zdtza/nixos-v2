import QtQuick
import Quickshell
import "../components"
import "../services"

// Right-aligned date and time panel opened from the bar clock.
Drawer {
    id: root

    contentSpacing: 14
    implicitWidth: 420
    implicitHeight: panelContent.implicitHeight
        + contentTopMargin + contentBottomMargin

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Hero {
        width: parent.width
        icon: "󰥔"
        title: "Clock"
        status: "LOCAL TIME"
    }

    Separator {}

    Column {
        width: parent.width
        spacing: 4

        ShellText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Qt.formatDateTime(clock.date, "HH:mm:ss")
            size: 32
            font.weight: Font.Medium
        }

        ShellText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Qt.formatDateTime(clock.date, "dd MMMM yyyy")
            opacity: 0.8
            size: 22
            font.weight: Font.Medium
        }

        ShellText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Qt.formatDateTime(clock.date, "dddd")
            opacity: 0.6
            size: 20
            font.weight: Font.Medium
        }
    }
}
