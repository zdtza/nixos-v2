import QtQuick
import "../services"

// Shared uppercase section heading with optional right-aligned status.
Item {
    id: root

    property string title: ""
    property string detail: ""

    width: parent ? parent.width : 0
    implicitHeight: Math.max(titleLabel.implicitHeight, detailLabel.implicitHeight)

    ShellText {
        id: titleLabel
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        color: Qt.darker(Theme.base05, 1.4)
        size: 11
        font.bold: true
        font.letterSpacing: 1
    }

    ShellText {
        id: detailLabel
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: root.detail
        visible: text !== ""
        color: Theme.base04
        size: 11
        font.bold: true
        font.letterSpacing: 1
    }
}
