import QtQuick
import "../services"
import ".."

Rectangle {
    id: box

    required property var launcher
    property alias text: input.text

    height: 34
    color: Theme.base01
    radius: height / 2
    border.width: 1
    border.color: PanelService.chromeBorderColor

    function focusInput(): void {
        input.forceActiveFocus();
    }

    ShellText {
        id: icon
        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
        text: "󰍉"
        color: Theme.textSecondary
        size: 15
    }

    TextInput {
        id: input
        anchors {
            left: icon.right
            right: parent.right
            leftMargin: 11
            rightMargin: 14
            verticalCenter: parent.verticalCenter
        }
        height: 26
        verticalAlignment: TextInput.AlignVCenter
        focus: true
        selectByMouse: true
        clip: true
        color: Theme.textPrimary
        selectionColor: Theme.base02
        selectedTextColor: Theme.textPrimary
        font.family: Theme.monospace
        font.pixelSize: Utils.scaledFont(13)
        cursorDelegate: Rectangle { width: 1; color: Theme.base05 }

        ShellText {
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            visible: input.text === ""
            text: box.launcher.keybindMode ? "Search keybindings" : "Search for apps"
            color: Theme.textSecondary
            size: 13
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                if (box.launcher.powerMenuOpen)
                    box.launcher.powerMenuOpen = false;
                else
                    box.launcher.open = false;
            } else if (event.key === Qt.Key_Down) {
                box.launcher.moveSelection(1);
            } else if (event.key === Qt.Key_Up) {
                box.launcher.moveSelection(-1);
            } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                    && !box.launcher.keybindMode) {
                box.launcher.activate(box.launcher.selectedItem);
            } else if (event.key === Qt.Key_C && event.modifiers === Qt.ControlModifier) {
                input.text = "";
            } else {
                return;
            }
            event.accepted = true;
        }
    }
}
