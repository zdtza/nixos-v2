pragma Singleton

// Persistent notification suppression state.
import QtQuick

PersistentToggle {
    stateFileName: "do-not-disturb-enabled"
    ipcTarget: "dnd"
    onMissing: setEnabled(false)
}
