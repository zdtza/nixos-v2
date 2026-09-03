import QtQuick
import Stylix
import ".."

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
        color: Qt.darker(Theme.base05, 1.4)
        font.family: Theme.monospace
        font.pixelSize: Utils.scaledFont(11)
        font.bold: true
        font.letterSpacing: 1
    }

    Text {
        id: detailLabel
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: root.detail
        visible: text !== ""
        color: Theme.base04
        font.family: Theme.monospace
        font.pixelSize: Utils.scaledFont(11)
        font.bold: true
        font.letterSpacing: 1
    }
}
