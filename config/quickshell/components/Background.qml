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

    // Two stacked images, swapped by z-order instead of by reassigning one
    // shared "source" -- reassigning source on the visible Image destroys its
    // GPU texture before the new one uploads, and since this is the bottom-
    // most wlr layer (nothing behind it to show through), that gap paints
    // black. Loading the next wallpaper into whichever image is currently
    // underneath means it's fully decoded and rendered (just occluded)
    // before it's ever raised on top, so the promotion is a z change with
    // no missing-texture frame.
    property bool topIsA: true

    Image {
        id: imgA
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        cache: true
        z: root.topIsA ? 1 : 0
        opacity: root.topIsA ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 400
                easing.type: Easing.InOutQuad
            }
        }
        // Synchronous on purpose: this is the one that bootstraps the very
        // first wallpaper on shell startup, before anything is on-screen to
        // occlude a loading frame.
        asynchronous: false
        onStatusChanged: if (status === Image.Ready && source === Theme.wallpaper && !root.topIsA) root.topIsA = true
    }

    Image {
        id: imgB
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        cache: true
        z: root.topIsA ? 0 : 1
        opacity: root.topIsA ? 0 : 1
        Behavior on opacity {
            NumberAnimation {
                duration: 400
                easing.type: Easing.InOutQuad
            }
        }
        asynchronous: true
        onStatusChanged: if (status === Image.Ready && source === Theme.wallpaper && root.topIsA) root.topIsA = false
    }

    Connections {
        target: Theme
        function onWallpaperChanged() {
            // Reassigning the same url is a silent no-op in QML (no property
            // change => no statusChanged => never promoted) -- this bites
            // exactly when reverting to a wallpaper this same back image
            // already held from an earlier swap. Clearing it first forces a
            // real Null -> Loading -> Ready transition every time.
            const back = root.topIsA ? imgB : imgA;
            back.source = "";
            back.source = Theme.wallpaper;
        }
    }

    Component.onCompleted: imgA.source = Theme.wallpaper
}
