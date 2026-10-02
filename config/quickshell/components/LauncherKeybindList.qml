pragma ComponentBehavior: Bound

import QtQuick
import "../services"
import ".."

ListView {
    id: list

    required property var launcher

    model: launcher.keybindRows
    spacing: 2
    clip: true
    header: Item { height: 16 }
    footer: Item { height: 16 }
    currentIndex: launcher.currentIndex
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
        height: 58
        radius: PanelService.rounding
        color: row.ListView.isCurrentItem
            ? Utils.alpha(Theme.base05, 0.11) : "transparent"

        ShellText {
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                topMargin: 9
                leftMargin: 12
                rightMargin: 12
            }
            text: row.modelData.chord
            elide: Text.ElideRight
            size: 12
        }

        ShellText {
            anchors {
                bottom: parent.bottom
                left: parent.left
                right: parent.right
                bottomMargin: 9
                leftMargin: 12
                rightMargin: 12
            }
            text: row.modelData.description
            color: Theme.textSecondary
            elide: Text.ElideRight
            size: 10
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onPositionChanged: list.launcher.currentIndex = row.index
        }
    }
}
