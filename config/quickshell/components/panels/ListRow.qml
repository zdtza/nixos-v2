import QtQuick
import "../primitives"
import "../../services"
import "../.."

// Selectable panel list row: icon, title over an optional subtitle, action
// buttons shown while selected, and a trailing status glyph.
Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property string trailingIcon: ""
    property real iconSize: 16
    property real titleSize: 12
    property int titleWeight: Font.Normal
    property real titleLeftMargin: 10
    // Keyboard/hover selection: outline, fill and visible actions.
    property bool selected: false
    // Applied choice (e.g. the default audio device): fill only.
    property bool current: false
    property bool clickable: true
    // Hides the row's own content and highlight so an overlay can take over the row in place.
    property bool contentHidden: false
    default property alias actions: actionRow.data
    property alias overlay: overlaySlot.data

    signal activated()
    // The pointer moved onto the row once hover-select is armed.
    signal hoverSelected()

    readonly property bool highlighted: selected && !contentHidden

    width: parent ? parent.width : 0
    height: 48
    radius: PanelService.rounding
    color: mouseArea.pressed && !contentHidden ? Utils.alpha(Theme.base05, 0.22)
        : highlighted ? Utils.alpha(Theme.base05, 0.10)
        : current ? Utils.alpha(Theme.base05, 0.08) : "transparent"
    border.width: highlighted ? 1 : 0
    border.color: Utils.alpha(Theme.base05, 0.25)

    HoverHandler {
        onHoveredChanged: if (hovered && PanelService.hoverSelectReady && !root.contentHidden)
            root.hoverSelected()
    }

    Item {
        anchors.fill: parent
        visible: !root.contentHidden

        ShellText {
            id: iconText
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            size: root.iconSize
        }

        Column {
            anchors.left: iconText.right
            anchors.leftMargin: root.titleLeftMargin
            anchors.right: actionRow.visible ? actionRow.left
                : trailingText.visible ? trailingText.left : parent.right
            anchors.rightMargin: actionRow.visible || trailingText.visible ? 8 : 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            ShellText {
                width: parent.width
                text: root.title
                size: root.titleSize
                font.weight: root.titleWeight
                elide: Text.ElideRight
            }

            ShellText {
                width: parent.width
                visible: text !== ""
                text: root.subtitle
                color: Theme.textSecondary
                size: 11
                elide: Text.ElideRight
            }
        }

        Row {
            id: actionRow
            z: 2
            visible: root.selected
            anchors.right: trailingText.visible ? trailingText.left : parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
        }

        ShellText {
            id: trailingText
            visible: text !== ""
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: root.trailingIcon
            color: Theme.textSecondary
            size: 12
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            z: 1
            enabled: root.clickable
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.activated()
        }
    }

    Item {
        id: overlaySlot
        anchors.fill: parent
    }
}
