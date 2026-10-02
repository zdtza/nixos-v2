pragma ComponentBehavior: Bound

import QtQuick
import "../services"

Rectangle {
    id: details

    required property var launcher
    readonly property var keybind: launcher.selectedKeybind

    visible: keybind !== null
    color: Theme.base00
    radius: PanelService.rounding
    border.width: 1
    border.color: PanelService.chromeBorderColor

    ShellText {
        id: icon
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 54 }
        text: details.launcher.keybindType(details.keybind) === "Mouse" ? "󰍽"
            : (details.launcher.keybindType(details.keybind) === "Switch" ? "󰜎" : "󰌌")
        size: 42
    }

    ShellText {
        id: chord
        anchors {
            top: icon.bottom
            left: parent.left
            right: parent.right
            topMargin: 18
            leftMargin: 20
            rightMargin: 20
        }
        horizontalAlignment: Text.AlignHCenter
        text: details.keybind?.chord ?? ""
        elide: Text.ElideRight
        font.bold: true
        size: 15
    }

    ShellText {
        id: description
        anchors {
            top: chord.bottom
            left: parent.left
            right: parent.right
            topMargin: 10
            leftMargin: 24
            rightMargin: 24
        }
        horizontalAlignment: Text.AlignHCenter
        text: details.keybind?.description ?? ""
        color: Theme.textSecondary
        wrapMode: Text.Wrap
        maximumLineCount: 3
        elide: Text.ElideRight
        size: 11
    }

    ShellText {
        id: options
        anchors {
            top: description.bottom
            left: parent.left
            right: parent.right
            topMargin: 10
            leftMargin: 24
            rightMargin: 24
        }
        horizontalAlignment: Text.AlignHCenter
        text: details.launcher.keybindOptions(details.keybind)
        color: Theme.textSecondary
        wrapMode: Text.Wrap
        size: 10
    }

    Column {
        anchors {
            top: options.bottom
            left: parent.left
            right: parent.right
            topMargin: 34
            leftMargin: 24
            rightMargin: 24
        }
        spacing: 16

        Repeater {
            model: [
                { label: "TYPE", value: details.launcher.keybindType(details.keybind) },
                { label: "TRIGGER", value: details.launcher.keybindTrigger(details.keybind) },
                { label: "MODIFIERS", value: details.launcher.modifierText(details.keybind) },
                { label: "KEY", value: details.launcher.keyName(String(details.keybind?.key ?? "")) }
            ]

            delegate: Item {
                required property var modelData
                width: parent.width
                height: 28

                ShellText {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    text: modelData.label
                    color: Theme.textSecondary
                    font.bold: true
                    font.letterSpacing: 1
                    size: 9
                }

                ShellText {
                    anchors {
                        left: parent.left
                        right: parent.right
                        leftMargin: 86
                        verticalCenter: parent.verticalCenter
                    }
                    text: modelData.value
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                    size: 11
                }
            }
        }
    }
}
