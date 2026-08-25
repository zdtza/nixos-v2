import QtQuick
import Stylix

// Shared uppercase section heading with optional right-aligned status.
Item {
    id: root

    property string title: ""
    property string detail: ""

    width: parent ? parent.width : 0
    implicitHeight: Math.max(titleLabel.implicitHeight, detailLabel.implicitHeight)

    Text {
        id: titleLabel
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        color: Qt.darker(Theme.foreground, 1.4)
        font.family: Theme.fontFamily
        font.pixelSize: Util.scaledFont(11)
        font.bold: true
        font.letterSpacing: 1
    }

    Text {
        id: detailLabel
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: root.detail
        visible: text !== ""
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: Util.scaledFont(11)
        font.bold: true
        font.letterSpacing: 1
    }
}
