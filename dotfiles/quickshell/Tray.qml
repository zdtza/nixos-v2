// StatusNotifierItem tray icons. Left click activates, right click opens menu.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Stylix
import Quickshell.Services.SystemTray

RowLayout {
    id: root

    spacing: 8

    Repeater {
        model: SystemTray.items

        Item {
            id: entry

            required property SystemTrayItem modelData

            implicitWidth: Theme.iconSize
            implicitHeight: Theme.iconSize

            Image {
                anchors.fill: parent
                source: entry.modelData.icon
                sourceSize.width: Theme.iconSize
                sourceSize.height: Theme.iconSize
                smooth: true
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                onClicked: mouse => {
                    if (mouse.button === Qt.LeftButton)
                        entry.modelData.activate();
                    else
                        menuAnchor.open();
                }
            }

            QsMenuAnchor {
                id: menuAnchor
                menu: entry.modelData.menu
                anchor.item: entry
                anchor.edges: Edges.Bottom
            }
        }
    }
}
