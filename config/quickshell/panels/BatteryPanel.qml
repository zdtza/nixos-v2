pragma ComponentBehavior: Bound

// Omarchy-style power panel backed by UPower and TLP's power-profile API.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Stylix
import "../components"
import "../services"
import ".."

Item {
    id: root

    readonly property bool available: BatteryService.available
    readonly property real fraction: BatteryService.fraction
    readonly property int percent: BatteryService.chargePercent
    readonly property bool discharging: BatteryService.isDischarging
    readonly property bool thresholdActive: BatteryService.thresholdActive
    readonly property bool fullyCharged: BatteryService.fullyCharged && !thresholdActive
    readonly property bool charging: BatteryService.isCharging && !thresholdActive
    readonly property bool low: discharging && percent <= 20
    readonly property var profiles: BatteryService.availableProfiles
    readonly property string activeProfile: BatteryService.powerProfile

    readonly property bool opened: PanelService.activePanel === root
    readonly property bool requiresKeyboardFocus: true
    property int phraseIndex: 0
    property int selectedProfileIndex: 0

    readonly property var chargingPhrases: [
        "Pumping power", "Injecting electrons", "Pouring juice", "Amassing watts",
        "Hoarding joules", "Sucking volts", "Topping reserves", "Soaking amps",
        "Inhaling kilowatts"
    ]
    readonly property var batteryPhrases: [
        "Slurping power", "Spending joules", "Draining watts", "Burning electrons",
        "Sipping juice", "Spending coulombs", "Bleeding amps", "Guzzling volts",
        "Munching reserves"
    ]
    readonly property var activePhrases: charging ? chargingPhrases : (discharging ? batteryPhrases : [])
    readonly property string statusText: fullyCharged ? "Fully charged"
        : thresholdActive ? "Threshold"
        : activePhrases.length > 0 ? activePhrases[phraseIndex % activePhrases.length] : "Battery"

    visible: available
    implicitWidth: available ? label.implicitWidth : 0
    implicitHeight: label.implicitHeight

    function batteryIcon(): string {
        return available ? BatteryService.batteryIcon : "";
    }

    function profileIcon(profile: string): string {
        if (profile === "PowerSaver")
            return "󰌪";
        if (profile === "Balanced")
            return "󰊚";
        if (profile === "Performance")
            return "󰓅";
        return "󰂄";
    }

    function setProfile(profile: string): void {
        BatteryService.setPowerProfile(profile);
    }

    onOpenedChanged: if (opened) {
        phraseIndex = 0;
        selectedProfileIndex = Math.max(0,
            profiles.findIndex(profile => String(profile) === activeProfile));
    }
    onAvailableChanged: if (!available)
        PanelService.close(root)

    Shortcut {
        enabled: root.opened
        sequence: "Left"
        context: Qt.ApplicationShortcut
        onActivated: root.selectedProfileIndex = Math.max(0, root.selectedProfileIndex - 1)
    }
    Shortcut {
        enabled: root.opened
        sequence: "Up"
        context: Qt.ApplicationShortcut
        onActivated: root.selectedProfileIndex = Math.max(0, root.selectedProfileIndex - 1)
    }
    Shortcut {
        enabled: root.opened
        sequence: "Right"
        context: Qt.ApplicationShortcut
        onActivated: root.selectedProfileIndex = Math.min(root.profiles.length - 1,
            root.selectedProfileIndex + 1)
    }
    Shortcut {
        enabled: root.opened
        sequence: "Down"
        context: Qt.ApplicationShortcut
        onActivated: root.selectedProfileIndex = Math.min(root.profiles.length - 1,
            root.selectedProfileIndex + 1)
    }
    Shortcut {
        enabled: root.opened && root.profiles.length > 0
        sequence: "Return"
        context: Qt.ApplicationShortcut
        onActivated: root.setProfile(String(root.profiles[root.selectedProfileIndex]))
    }
    Shortcut {
        enabled: root.opened && root.profiles.length > 0
        sequence: "Enter"
        context: Qt.ApplicationShortcut
        onActivated: root.setProfile(String(root.profiles[root.selectedProfileIndex]))
    }

    StatusRotator {
        target: batteryHero.statusLabel
        running: root.opened && root.activePhrases.length > 0
        onAdvance: {
            if (root.activePhrases.length > 0)
                root.phraseIndex = (root.phraseIndex + 1) % root.activePhrases.length;
        }
    }

    Button {
        id: label
        anchors.centerIn: parent
        panel: root
        text: root.batteryIcon()
        textColor: root.low ? Theme.base08 : Theme.base05
        onClicked: PanelService.toggle(root)
    }

    HyprlandFocusGrab {
        active: root.opened
        windows: [panel, root.QsWindow.window]
        onCleared: PanelService.close(root)
    }

    Drawer {
        id: panel
        anchorItem: root
        anchorWindow: root.QsWindow.window
        open: root.opened
        onCloseRequested: PanelService.close(root)
        contentSpacing: 14
        // Wider card gives each equal-width profile button real horizontal
        // breathing room around its icon and longest label (Power-saver).
        implicitWidth: 420 + PanelService.shellRounding
        implicitHeight: panelContent.implicitHeight
            + contentTopMargin + contentBottomMargin

        Hero {
            id: batteryHero
            width: parent.width
            icon: root.batteryIcon()
            title: "Battery"
            status: root.statusText.toUpperCase()
            trailingWidth: heroPercent.implicitWidth
            trailingHeight: heroPercent.implicitHeight
            trailingMargin: 10

            Text {
                id: heroPercent
                anchors.centerIn: parent
                text: root.percent + "%"
                color: Theme.base05
                font.family: Theme.monospace
                font.pixelSize: Utils.scaledFont(30)
                font.bold: true
            }
        }

        Item {
            width: parent.width
            implicitHeight: 8

            Rectangle {
                id: chargeTrack
                anchors.fill: parent
                radius: height / 2
                color: Utils.alpha(Theme.base05, 0.12)
            }
            Rectangle {
                anchors.left: chargeTrack.left
                anchors.verticalCenter: chargeTrack.verticalCenter
                height: chargeTrack.height
                width: Math.max(height, chargeTrack.width * root.fraction)
                radius: height / 2
                color: Theme.base05
                Behavior on width {
                    NumberAnimation {
                        duration: 320
                        easing.type: Easing.OutCubic
                    }
                }
                SequentialAnimation on opacity {
                    running: root.charging && root.opened
                    loops: Animation.Infinite
                    NumberAnimation {
                        from: 1
                        to: 0.55
                        duration: 950
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        from: 0.55
                        to: 1
                        duration: 950
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }

        Row {
            id: batteryMetrics
            width: parent.width
            spacing: 20

            Column {
                width: (batteryMetrics.width - batteryMetrics.spacing) / 2
                spacing: 12
                InfoPair {
                    labelText: "Battery size"
                    valueText: BatteryService.batterySizeWh > 0
                        ? Math.round(BatteryService.batterySizeWh) + "Wh" : "—"
                }
                InfoPair {
                    labelText: "Charge cycles"
                    valueText: BatteryService.chargeCycles >= 0
                        ? String(BatteryService.chargeCycles) : "—"
                }
            }
            Column {
                width: (batteryMetrics.width - batteryMetrics.spacing) / 2
                spacing: 12
                InfoPair {
                    labelText: root.thresholdActive ? "Charge limit"
                        : (root.discharging ? "Time left" : "Time to full")
                    valueText: root.thresholdActive ? (BatteryService.chargeThreshold || "—")
                        : (root.fullyCharged ? "—"
                            : BatteryService.formatDuration(BatteryService.secondsRemaining))
                }
                InfoPair {
                    labelText: root.thresholdActive ? "Battery state"
                        : (root.discharging ? "Discharging" : "Charging")
                    valueText: root.thresholdActive ? "Holding"
                        : (root.fullyCharged ? "—"
                            : (BatteryService.changeRate > 0
                                ? BatteryService.changeRate.toFixed(1).replace(/\\.0$/, "") + "W" : "—"))
                }
            }
        }

        Separator {}

        Column {
            width: parent.width
            spacing: 10

            SectionHeader {
                title: "POWER PROFILE"
            }

            Row {
                id: profileRow
                width: parent.width
                spacing: 6
                readonly property real cellWidth: root.profiles.length > 0
                    ? (width - spacing * (root.profiles.length - 1)) / root.profiles.length : 0

                Repeater {
                    model: root.profiles
                    OptionButton {
                        id: profileButton
                        required property var modelData
                        required property int index
                        readonly property bool isActive: root.activeProfile === String(modelData)

                        width: profileRow.cellWidth
                        height: 36
                        active: profileButton.isActive
                        keyboardFocused: profileButton.index === root.selectedProfileIndex
                        onHoveredChanged: if (hovered)
                            root.selectedProfileIndex = profileButton.index
                        onActivated: {
                            root.selectedProfileIndex = profileButton.index;
                            root.setProfile(String(profileButton.modelData));
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.profileIcon(String(profileButton.modelData))
                                color: Theme.base05
                                font.family: Theme.monospace
                                font.pixelSize: Utils.scaledFont(15)
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: String(profileButton.modelData) === "PowerSaver"
                                    ? "Power-saver" : String(profileButton.modelData)
                                color: Theme.base05
                                font.family: Theme.monospace
                                font.pixelSize: Utils.scaledFont(12)
                            }
                        }
                    }
                }
            }
        }
    }

    component InfoPair: Row {
        property string labelText: ""
        property string valueText: ""
        width: parent.width
        spacing: 8

        Text {
            text: parent.labelText
            color: Theme.base05
            opacity: 0.6
            font.family: Theme.monospace
            font.pixelSize: Utils.scaledFont(12)
        }
        Item {
            width: Math.max(0, parent.width
                - parent.children[0].implicitWidth - parent.children[2].implicitWidth - 16)
            height: 1
        }
        Text {
            text: parent.valueText
            color: Theme.base05
            font.family: Theme.monospace
            font.pixelSize: Utils.scaledFont(12)
        }
    }
}
