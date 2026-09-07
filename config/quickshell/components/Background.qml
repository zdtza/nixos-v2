// Desktop wallpaper, rendered by quickshell itself at the wlr-layer-shell
// background layer -- this replaced a hyprpaper daemon (removed from the
// repo) so future wallpaper-switch animations/effects can live here in QML
// instead of being limited to an external IPC swap.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"

PanelWindow {
    id: root

    required property var modelData

    screen: modelData
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.namespace: "quickshell:background"
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    // Background-layer surfaces don't need input at all; keep it fully
    // click-through, same idiom Bar.qml uses to go non-interactive.
    mask: Region {
        width: 0
        height: 0
    }

    // "shown" stays on the previous wallpaper until "preloader" (invisible,
    // asynchronous) finishes decoding the new one -- swapping instantly only
    // once it's ready avoids the black flash of binding straight to
    // Theme.wallpaper while the new image is still loading.
    Image {
        id: shown
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        // Synchronous here on purpose: source is only ever assigned once
        // preloader below confirms it's already decoded and cached, so this
        // grabs it straight from cache with no gap -- asynchronous: true
        // could still paint one blank frame first even on a cache hit.
        asynchronous: false
        cache: true
    }

    Image {
        id: preloader
        visible: false
        asynchronous: true
        cache: true
        source: Theme.wallpaper
        onStatusChanged: if (status === Image.Ready) shown.source = source
    }

    Component.onCompleted: shown.source = Theme.wallpaper
}
