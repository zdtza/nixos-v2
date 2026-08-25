import QtQuick
import Stylix

// Shared panel heading: icon, title/status labels, optional trailing control.
Item {
    id: root

    property string icon: ""
    property string title: ""
    property string status: ""
    property real trailingWidth: 0
    property real trailingHeight: 0
    property real trailingMargin: 14
    default property alias trailingData: trailingSlot.data
    readonly property alias statusLabel: statusText

    implicitHeight: Math.max(heroIcon.implicitHeight, labels.implicitHeight, trailingSlot.implicitHeight)

    Text {
        id: heroIcon
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: Util.scaledFont(26)
    }

    Column {
        id: labels
        anchors.left: heroIcon.right
        anchors.leftMargin: 14
        anchors.right: trailingSlot.left
        anchors.rightMargin: root.trailingMargin
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            width: parent.width
            text: root.title
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Util.scaledFont(15)
            font.bold: true
            elide: Text.ElideRight
        }

        Text {
            id: statusText
            width: parent.width
            text: root.status
            color: Qt.darker(Theme.foreground, 1.4)
            font.family: Theme.fontFamily
            font.pixelSize: Util.scaledFont(11)
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
