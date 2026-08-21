// Title of the currently focused Hyprland toplevel.
import QtQuick
import Quickshell.Hyprland
import Stylix

Text {
    readonly property var toplevel: Hyprland.activeToplevel

    text: toplevel && toplevel.title ? toplevel.title : "Desktop"
    elide: Text.ElideRight
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    color: Theme.muted
}
