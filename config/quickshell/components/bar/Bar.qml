// Layer-shell bar laid out from BarConfig.
import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Wayland
import "../../panels"
import "../../services"

PanelWindow {
    id: bar

    required property var modelData

    // Panels with no place in the layout, always hosted so keybinds reach them.
    // Panels that are bar items register themselves as they are created.
    readonly property var panelEntries: [
        ["launcher", launcher],
        ["nightlight", nightLight],
        ["timer", timer],
        ["monitor", monitor]
    ]

    // The centre item that stays fixed mid-bar, with the rest of `center` either side.
    readonly property int pivotIndex: {
        const index = BarConfig.center.indexOf(BarConfig.centerPivot);
        return index >= 0 ? index : Math.floor((BarConfig.center.length - 1) / 2);
    }

    Component.onCompleted: {
        for (const entry of panelEntries)
            PanelService.registerPanel(entry[0], entry[1], bar.screen);
    }
    Component.onDestruction: {
        for (const entry of panelEntries)
            PanelService.unregisterPanel(entry[0], entry[1]);
    }

    // A hidden bar flies out over windows while the pointer is on it.
    readonly property bool peeking: PanelService.barPeeking
        && PanelService.barPeekScreen === (screen?.name ?? "")
    readonly property bool shown: PanelService.barVisible || peeking

    // 1 when out, 0 when tucked away; drives the slide.
    property real reveal: shown ? 1 : 0
    Behavior on reveal {
        NumberAnimation { duration: PanelService.slideDuration; easing.type: Easing.OutCubic }
    }

    // Shared by the background and every section, so they slide in from the bar's edge as one.
    Translate {
        id: slide
        y: (1 - bar.reveal) * PanelService.barHeight * (PanelService.barAtTop ? -1 : 1)
    }

    screen: modelData
    color: "transparent"
    // Hidden, it shrinks to a 1px strip along its edge that the pointer can hit,
    // once the slide away has finished.
    implicitHeight: shown || reveal > 0 ? PanelService.barHeight : 1
    // Only a pinned bar reserves space; a flown-out one overlaps windows.
    exclusionMode: PanelService.barVisible ? ExclusionMode.Auto : ExclusionMode.Ignore

    mask: Region {
        width: bar.width
        height: bar.shown ? bar.height : 1
    }

    // Stays out while a panel opened from it is up, otherwise tucks away as soon as the pointer leaves.
    function updatePeek(): void {
        if (PanelService.barVisible)
            return;
        if (barHover.hovered)
            PanelService.barPeekScreen = screen?.name ?? "";
        else if (peeking && !PanelService.activePanel)
            PanelService.barPeekScreen = "";
    }

    HoverHandler {
        id: barHover
        onHoveredChanged: bar.updatePeek()
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.base01
        transform: slide
    }

    Connections {
        target: PanelService
        function onActivePanelChanged(): void {
            if (bar.peeking && !PanelService.activePanel)
                bar.updatePeek();
        }
    }

    WlrLayershell.namespace: "quickshell:bar"
    WlrLayershell.keyboardFocus: PanelService.activePanel?.requiresKeyboardFocus
        && !PanelService.refocusing
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None


    anchors {
        top: PanelService.barAtTop
        bottom: !PanelService.barAtTop
        left: true
        right: true
    }

    // Popup focus grabs include bar so controls remain directly clickable.
    MouseArea {
        anchors.fill: parent
        onClicked: PanelService.closeActive()
    }

    // Panel keyboard hosting.
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
        // Loader is a focus scope, so this plus `focus: true` on the proxy itself is what actually lands active focus inside it.
        active: !!bar.activeKeyboardProxy
        focus: active
        sourceComponent: bar.activeKeyboardProxy
    }

    // Hosts for panels opened by keybind or from other items; the drawers
    // position themselves, so these take no room.
    LauncherPanel { id: launcher }
    MonitorPanel { id: monitor }
    NightLightTogglePanel { id: nightLight }
    TimerTogglePanel { id: timer }

    Row {
        anchors {
            left: parent.left
            leftMargin: 8
            verticalCenter: parent.verticalCenter
        }
        spacing: PanelService.barSpacing
        transform: slide

        Repeater {
            model: BarConfig.start
            delegate: barItems
        }
    }

    Row {
        anchors {
            right: centerPivot.left
            rightMargin: centerPivot.width > 0 ? PanelService.barSpacing : 0
            verticalCenter: parent.verticalCenter
        }
        spacing: PanelService.barSpacing
        transform: slide

        Repeater {
            model: BarConfig.center.slice(0, bar.pivotIndex)
            delegate: barItems
        }
    }

    Row {
        id: centerPivot
        anchors.centerIn: parent
        transform: slide

        Repeater {
            model: BarConfig.center.slice(bar.pivotIndex, bar.pivotIndex + 1)
            delegate: barItems
        }
    }

    Row {
        anchors {
            left: centerPivot.right
            leftMargin: centerPivot.width > 0 ? PanelService.barSpacing : 0
            verticalCenter: parent.verticalCenter
        }
        spacing: PanelService.barSpacing
        transform: slide

        Repeater {
            model: BarConfig.center.slice(bar.pivotIndex + 1)
            delegate: barItems
        }
    }

    Row {
        anchors {
            right: parent.right
            rightMargin: 12
            verticalCenter: parent.verticalCenter
        }
        spacing: PanelService.barSpacing
        transform: slide

        Repeater {
            model: BarConfig.end
            delegate: barItems
        }
    }

    // Neighbours of an item within its section, for items that cooperate.
    function neighbours(item: string): var {
        const list = BarConfig.sections[BarConfig.sectionOf(item)] ?? [];
        const index = list.indexOf(item);
        return { before: list[index - 1] ?? "", after: list[index + 1] ?? "" };
    }

    DelegateChooser {
        id: barItems
        role: "modelData"

        DelegateChoice {
            roleValue: "workspaces"
            Workspaces { screen: bar.screen }
        }

        DelegateChoice {
            roleValue: "minimised"
            MinimisedBadge { screen: bar.screen }
        }

        DelegateChoice {
            roleValue: "quickToggles"
            QuickToggles {
                nightLightPanel: nightLight
                timerPanel: timer
                // After the clock, the toggles grow away from it towards the end.
                mirrored: bar.neighbours("quickToggles").before === "clock"
            }
        }

        DelegateChoice {
            roleValue: "clock"
            Clock {
                id: clockItem
                timerPanel: timer
                PanelRegistration { name: "clock"; panel: clockItem }
            }
        }

        DelegateChoice {
            roleValue: "timer"
            TimerBadge { panelTarget: timer }
        }

        DelegateChoice {
            roleValue: "tray"
            Tray {
                id: trayItem
                PanelRegistration { name: "tray"; panel: trayItem }
            }
        }

        DelegateChoice {
            roleValue: "bluetooth"
            BluetoothPanel {
                id: bluetoothItem
                PanelRegistration { name: "bluetooth"; panel: bluetoothItem }
            }
        }

        DelegateChoice {
            roleValue: "audio"
            AudioPanel {
                id: audioItem
                PanelRegistration { name: "audio"; panel: audioItem }
            }
        }

        DelegateChoice {
            roleValue: "battery"
            BatteryPanel {
                id: batteryItem
                PanelRegistration { name: "battery"; panel: batteryItem }
            }
        }

        DelegateChoice {
            roleValue: "network"
            NetworkPanel {
                id: networkItem
                PanelRegistration { name: "network"; panel: networkItem }
            }
        }
    }

    // Registers a bar item's panel for `qs ipc call panels toggle <name>` while it exists.
    component PanelRegistration: QtObject {
        required property string name
        required property var panel

        Component.onCompleted: PanelService.registerPanel(name, panel, bar.screen)
        Component.onDestruction: PanelService.unregisterPanel(name, panel)
    }
}
