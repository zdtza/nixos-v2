pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../services"
import ".."

ListView {
    id: list

    required property var launcher
    property real rowHeight: 50
    property real iconSize: 28
    property real iconLeftMargin: 12
    property real textLeftMargin: 12
    property real textRightMargin: 12
    property color selectedColor: Utils.alpha(Theme.base05, 0.11)

    spacing: 2
    clip: true
    header: Item { height: 16 }
    footer: Item { height: 16 }
    currentIndex: launcher.currentIndex
    highlightMoveDuration: 0
    highlightResizeDuration: 0
    boundsBehavior: Flickable.StopAtBounds
    maximumFlickVelocity: 12000

    WheelHandler {
        blocking: true
        onWheel: event => list.launcher.scrollListByWheel(list, event)
    }

    delegate: Rectangle {
        id: row

        required property var modelData
        required property int index

        width: ListView.view.width
        height: list.rowHeight
        radius: PanelService.rounding
        color: row.ListView.isCurrentItem ? list.selectedColor : "transparent"

        Image {
            id: icon

            anchors {
                left: parent.left
                leftMargin: list.iconLeftMargin
                verticalCenter: parent.verticalCenter
            }
            width: list.iconSize
            height: list.iconSize
            source: row.modelData.entry.icon
                ? Quickshell.iconPath(row.modelData.entry.icon, true) : ""
            sourceSize.width: 48
            sourceSize.height: 48
            asynchronous: true
            smooth: true
        }

        ShellText {
            anchors {
                left: icon.right
                right: parent.right
                leftMargin: list.textLeftMargin
                rightMargin: list.textRightMargin
                verticalCenter: parent.verticalCenter
            }
            text: row.modelData.entry.name
            elide: Text.ElideRight
            size: 13
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            // A stationary pointer must not select a different result when
            // typing replaces the rows underneath it.
            onPositionChanged: list.launcher.currentIndex = row.index
            onClicked: list.launcher.activate(row.modelData)
        }
    }
}
