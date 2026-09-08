// Top bar layer-shell panel. Three anchored groups: left, right, and a clock
// pinned to the true center of the bar (independent of the side widths).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../panels"
import "../services"

PanelWindow {
    id: bar

    required property var modelData

    function panelEntries(): var {
        return [
            ["calendar", clock],
            ["nightlight", quickToggles.nightLightPanel],
            ["timer", quickToggles.timerPanel],
            ["tray", tray],
            ["volume", volume],
            ["bluetooth", bluetooth],
            ["display", display],
            ["network", network],
            ["battery", battery]
        ];
    }

    function registerPanels(): void {
        for (const entry of panelEntries())
            PanelService.registerPanel(entry[0], entry[1], bar.screen);
    }

    function unregisterPanels(): void {
        for (const entry of panelEntries())
            PanelService.unregisterPanel(entry[0], entry[1]);
    }

    Component.onCompleted: registerPanels()
    Component.onDestruction: unregisterPanels()

    screen: modelData
    // Layer-shell surfaces cannot stay mapped at zero height. Keep a
    // non-exclusive transparent pixel above the output so popup anchors survive.
    color: PanelService.barVisible ? Theme.base01 : "transparent"
    implicitHeight: PanelService.barVisible ? PanelService.barHeight : 1
    exclusionMode: PanelService.barVisible ? ExclusionMode.Auto : ExclusionMode.Ignore

    mask: Region {
        width: PanelService.barVisible ? bar.width : 0
        height: PanelService.barVisible ? bar.height : 0
    }

    WlrLayershell.namespace: "quickshell:bar"
    WlrLayershell.keyboardFocus: PanelService.activePanel?.requiresKeyboardFocus
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors {
        top: true
        left: true
        right: true
    }
    margins.top: PanelService.barVisible ? 0 : -1

    PanelWindow {
        screen: bar.screen
        visible: PanelService.barVisible
        color: "transparent"
        implicitHeight: 36
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.namespace: "quickshell:bar-shadow"
        WlrLayershell.layer: WlrLayer.Top

        anchors {
            top: true
            left: true
            right: true
        }
        margins.top: PanelService.barHeight

        mask: Region { width: 0; height: 0 }

        Rectangle {
            y: -PanelService.barHeight
            width: parent.width
            height: PanelService.barHeight
            color: Theme.base01
            layer.enabled: true
            layer.effect: ShellShadow {}
        }
    }

    // Popup focus grabs include bar so controls remain directly clickable.
    // This background target dismisses active popup when unused bar area is hit.
    MouseArea {
        anchors.fill: parent
        onClicked: PanelService.closeActive()
    }

    // Panel keyboard hosting. Drawer and popup surfaces don't own compositor
    // keyboard focus, so whatever a panel needs focused has to live in the
    // bar window instead.
    //
    // Panels that only use application-wide shortcuts just need *something*
    // here focused, which is the stub below. A panel that also needs real
    // text entry publishes a `keyboardProxy` component (see PanelService for
    // the contract) and the Loader mounts it -- so the bar hosts the input
    // without knowing whether it's a countdown, a passphrase, or anything
    // added later.
    readonly property Component activeKeyboardProxy:
        PanelService.activePanel?.keyboardProxy ?? null

    Item {
        width: 1
        height: 1
        opacity: 0
        focus: !bar.activeKeyboardProxy
            && !!PanelService.activePanel?.requiresKeyboardFocus
    }

    Loader {
        x: -10
        width: 1
        height: 1
        opacity: 0
        // Loader is a focus scope, so this plus `focus: true` on the proxy
        // itself is what actually lands active focus inside it.
        active: !!bar.activeKeyboardProxy
        focus: active
        sourceComponent: bar.activeKeyboardProxy
    }

    // --- left ---
    RowLayout {
        spacing: PanelService.barSpacing
        anchors {
            leftMargin: 6
            left: parent.left
            verticalCenter: parent.verticalCenter
        }

        Workspaces {
            screen: bar.screen
        }
    }

    // --- center ---
    Clock {
        id: clock
        anchors.centerIn: parent
    }

    TimerBadge {
        id: timerBadge
        anchors {
            left: clock.right
            leftMargin: PanelService.barSpacing
            verticalCenter: clock.verticalCenter
        }
        panelTarget: quickToggles.timerPanel
    }

    QuickToggles {
        id: quickToggles

        anchors {
            right: clock.left
            // Clock and toggle slots both include transparent horizontal
            // padding. Pull their bounds together so visible content keeps
            // the same compact gap as neighboring bar icons.
            rightMargin: PanelService.barSpacing - 8
            verticalCenter: clock.verticalCenter
        }
    }

    // --- right ---
    RowLayout {
        spacing: PanelService.barSpacing
        anchors {
            right: parent.right
            rightMargin: 12
            verticalCenter: parent.verticalCenter
        }

        Tray { id: tray }

        VolumePanel {
            id: volume
            screen: bar.screen
        }

        BluetoothPanel { id: bluetooth }

        DisplayPanel {
            id: display
            screen: bar.screen
        }

        NetworkPanel { id: network }

        BatteryPanel { id: battery }
    }
}
