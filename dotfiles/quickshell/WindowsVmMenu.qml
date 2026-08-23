pragma ComponentBehavior: Bound

// Menu for the synthetic Windows VM tray entry. Mirrors TrayMenu's anchoring
// and styling so it is indistinguishable from a real tray item's menu, but is
// driven by a plain action list instead of a DBus menu handle.
import QtQuick
import Quickshell
import Stylix

PopupWindow {
    id: menu

    // Objects of { label, command }, where command is an argv array.
    required property var actions
    // Item and bar window this menu is positioned against.
    required property Item anchorItem
    required property var anchorWindow

    property int menuWidth: 220
    property string menuTitle: ""
    property string menuStatus: ""

    // Matches TrayMenu's interface so Tray.qml can treat both the same way when
    // building the focus grab's window list.
    readonly property var openWindows: [menu]

    signal closeRequested
    signal actionTriggered(command: var)

    Shortcut {
        enabled: menu.visible
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        onActivated: menu.closeRequested()
    }

    anchor {
        id: popupAnchor

        window: menu.anchorWindow
        edges: Edges.Top | Edges.Left
        gravity: Edges.Bottom | Edges.Right
        adjustment: PopupAdjustment.Slide
        rect.width: 1
        rect.height: 1

        // Match PanelPopup positioning: center under bar item, then leave same
        // compositor-gap-sized offset below bar.
        onAnchoring: {
            if (!menu.anchorWindow)
                return;

            let point = menu.anchorWindow.contentItem.mapFromItem(
                menu.anchorItem,
                menu.anchorItem.width / 2 - menu.implicitWidth / 2,
                menu.anchorItem.height + PanelService.barGap
            );
            point.x = Math.max(5, Math.min(point.x,
                menu.anchorWindow.width - menu.implicitWidth - 7));
            popupAnchor.rect.x = Math.round(point.x);
            popupAnchor.rect.y = Math.round(point.y);
        }
    }

    implicitWidth: menu.menuWidth
    implicitHeight: Math.max(1, column.implicitHeight + 12)
    // PopupWindow defaults to hidden. TrayMenu delays this until QsMenuOpener
    // has populated; this menu's model is static, so it can map immediately.
    visible: true
    color: "transparent"

    Rectangle {
        anchors.fill: parent

        color: Theme.background
        radius: 0
        border.width: 2
        border.color: Theme.border

        Column {
            id: column

            anchors {
                fill: parent
                leftMargin: 2
                rightMargin: 2
                topMargin: 6
                bottomMargin: 6
            }

            Item {
                width: column.width
                implicitHeight: menu.menuTitle === "" ? 0 : (menu.menuStatus === "" ? 44 : 58)
                visible: implicitHeight > 0

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.top: parent.top
                    anchors.topMargin: 12
                    text: menu.menuTitle
                    color: Theme.foreground
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    font.letterSpacing: 0.1
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.top: parent.top
                    anchors.topMargin: 32
                    visible: menu.menuStatus !== ""
                    text: menu.menuStatus.toUpperCase()
                    color: Theme.muted
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.Medium
                    font.letterSpacing: 1.8
                }
            }

            Rectangle {
                width: column.width
                implicitHeight: menu.menuTitle === "" ? 0 : 1
                visible: implicitHeight > 0
                color: Theme.border
            }

            Repeater {
                model: menu.actions

                Item {
                    id: row

                    required property var modelData

                    width: column.width
                    implicitHeight: 30

                    Rectangle {
                        anchors {
                            fill: parent
                            leftMargin: 6
                            rightMargin: 6
                        }
                        color: rowMouse.containsMouse ? Theme.surface : "transparent"

                        Text {
                            anchors {
                                left: parent.left
                                leftMargin: 14
                                right: parent.right
                                rightMargin: 8
                                verticalCenter: parent.verticalCenter
                            }
                            text: row.modelData.label
                            color: Theme.foreground
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                        }

                        MouseArea {
                            id: rowMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                menu.actionTriggered(row.modelData.command);
                                menu.closeRequested();
                            }
                        }
                    }
                }
            }
        }
    }
}
