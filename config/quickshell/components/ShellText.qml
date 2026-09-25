import QtQuick
import "../services"
import ".."

// Every label in the shell is monospace, theme-coloured, and sized through Utils.scaledFont so the one global readability offset.
Text {
    property real size: Theme.fontSize

    color: Theme.textPrimary
    font.family: Theme.monospace
    font.pixelSize: Utils.scaledFont(size)
}
