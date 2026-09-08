import QtQuick
import "../services"
import ".."

// Every label in the shell is monospace, theme-coloured, and sized through
// Utils.scaledFont so the one global readability offset reaches all of them.
// This carries those three defaults so call sites stop restating them; each
// is a plain default, so overriding `color` or `font` still works as normal.
//
// `size` is the pre-adjustment size, i.e. what used to be written as
// `font.pixelSize: Utils.scaledFont(n)`.
Text {
    property real size: Theme.fontSize

    color: Theme.base05
    font.family: Theme.monospace
    font.pixelSize: Utils.scaledFont(size)
}
