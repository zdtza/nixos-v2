import QtQuick
import Quickshell
import "../services"
import ".."

Rectangle {
    id: details

    required property var launcher
    readonly property var selectedItem: launcher.selectedItem

    visible: selectedItem !== null
    color: Theme.base00
    radius: PanelService.rounding
    border.width: 1
    border.color: PanelService.chromeBorderColor

    Image {
        id: icon
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 54 }
        width: 64
        height: 64
        source: details.selectedItem?.entry?.icon
            ? Quickshell.iconPath(details.selectedItem.entry.icon, true) : ""
        sourceSize.width: 96
        sourceSize.height: 96
        asynchronous: true
        smooth: true
    }

    ShellText {
        id: name
        anchors { top: icon.bottom; left: parent.left; right: parent.right; topMargin: 18; leftMargin: 18; rightMargin: 18 }
        horizontalAlignment: Text.AlignHCenter
        text: details.selectedItem?.entry?.name ?? ""
        elide: Text.ElideRight
        font.bold: true
        size: 16
    }

    ShellText {
        id: description
        anchors { top: name.bottom; left: parent.left; right: parent.right; topMargin: 8; leftMargin: 24; rightMargin: 24 }
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        maximumLineCount: 3
        elide: Text.ElideRight
        text: details.selectedItem?.entry?.comment
            || details.selectedItem?.entry?.genericName || "Application"
        color: Theme.textSecondary
        size: 11
    }

    ShellText {
        anchors {
            top: description.bottom
            left: parent.left
            right: parent.right
            topMargin: 8
            leftMargin: 20
            rightMargin: 20
        }
        horizontalAlignment: Text.AlignHCenter
        text: details.launcher.categoryText(details.selectedItem)
        visible: text !== ""
        color: Theme.textSecondary
        elide: Text.ElideRight
        size: 10
    }

    Column {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 22 }
        spacing: 8

        Rectangle {
            width: parent.width
            height: 40
            color: openMouse.containsMouse ? Utils.alpha(Theme.base05, 0.16) : Theme.base02
            radius: PanelService.rounding
            border.width: 1
            border.color: PanelService.chromeBorderColor

            ShellText { anchors.centerIn: parent; text: "OPEN  ↗"; font.bold: true; size: 12 }

            MouseArea {
                id: openMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: details.launcher.activate(details.selectedItem)
            }
        }

        Rectangle {
            width: parent.width
            height: visible ? 36 : 0
            visible: details.selectedItem !== null && !details.selectedItem.isFallback
                && !details.selectedItem.isSystemAction
            color: pinMouse.containsMouse ? Utils.alpha(Theme.base05, 0.12) : "transparent"
            radius: PanelService.rounding
            border.width: 1
            border.color: PanelService.chromeBorderColor

            ShellText {
                anchors.centerIn: parent
                text: details.launcher.isPinned(details.selectedItem)
                    ? "UNPIN FROM START" : "PIN TO START"
                size: 11
            }

            MouseArea {
                id: pinMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: details.launcher.togglePinned(details.selectedItem)
            }
        }
    }
}
