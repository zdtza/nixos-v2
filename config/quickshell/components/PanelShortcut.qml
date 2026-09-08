import QtQuick

// Application-scoped key binding.
//
// Exists so the shell's ~70 shortcuts stop repeating
// `context: Qt.ApplicationShortcut`, and so aliases for one action collapse
// into a single declaration through Shortcut's own `sequences` list rather
// than a near-identical block each -- Return/Enter and Left/Up really are one
// binding, and reading them as two obscured that.
Shortcut {
    context: Qt.ApplicationShortcut
}
