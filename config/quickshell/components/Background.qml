// Desktop wallpaper, rendered by quickshell itself at the wlr-layer-shell background layer.
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

    // Background-layer surfaces don't need input at all; keep it fully click-through, same idiom Bar.qml uses to go non-interactive.
    mask: Region {
        width: 0
        height: 0
    }

    // Two stacked images, swapped by z-order instead of by reassigning one shared "source".
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
        // Synchronous on purpose.
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
            // Reassigning the same url is a silent no-op in QML.
            const back = root.topIsA ? imgB : imgA;
            back.source = "";
            back.source = Theme.wallpaper;
        }
    }

    Component.onCompleted: imgA.source = Theme.wallpaper
}
