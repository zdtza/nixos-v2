import QtQuick
import "../services"

// Shared panel heading: icon, title/status labels, optional trailing control.
Item {
    id: root

    property string icon: ""
    property real iconSize: 20
    property string title: ""
    property string status: ""
    property real trailingWidth: 0
    property real trailingHeight: 0
    property real trailingMargin: 14
    default property alias trailingData: trailingSlot.data
    readonly property alias statusLabel: statusText

    implicitHeight: Math.max(heroIcon.implicitHeight, labels.implicitHeight, trailingSlot.implicitHeight)

    ShellText {
        id: heroIcon
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon
        size: root.iconSize
    }

    Column {
        id: labels
        anchors.left: heroIcon.right
        anchors.leftMargin: 14
        anchors.right: trailingSlot.left
        anchors.rightMargin: root.trailingMargin
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        ShellText {
            width: parent.width
            text: root.title
            size: 15
            font.bold: true
            elide: Text.ElideRight
        }

        ShellText {
            id: statusText
            width: parent.width
            text: root.status
            color: Theme.textSecondary
            size: 11
            font.bold: true
            font.letterSpacing: 1.2
            elide: Text.ElideRight
        }
    }

    Item {
        id: trailingSlot
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: root.trailingWidth
        implicitHeight: root.trailingHeight
    }
}
