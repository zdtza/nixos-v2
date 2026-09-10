// Red outline around the screen being shared, so a live cast is obvious from
// the screen itself and not only from the bar indicator. One instance per
// connected screen (shell.qml); only the one whose output the picker selected
// makes itself visible.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"

PanelWindow {
    id: root

    required property var modelData

    screen: modelData
    visible: ScreenShareService.outputName === modelData.name
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    // Overlay layer: above fullscreen windows too, since those are exactly
    // what a call is usually sharing.
    WlrLayershell.namespace: "quickshell:share-border"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    // Fully click-through, same idiom Background.qml uses: an empty input
    // region means the compositor never routes a click here.
    mask: Region {
        width: 0
        height: 0
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: Theme.base08
        border.width: 1
    }
}
