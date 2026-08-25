pragma ComponentBehavior: Bound

// Omarchy-style power panel backed by UPower and TLP's power-profile API.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Stylix

Item {
    id: root

    readonly property bool available: ServiceBattery.available
    readonly property real fraction: ServiceBattery.fraction
    readonly property int percent: ServiceBattery.chargePercent
    readonly property bool discharging: ServiceBattery.isDischarging
    readonly property bool thresholdActive: ServiceBattery.thresholdActive
    readonly property bool fullyCharged: ServiceBattery.fullyCharged && !thresholdActive
    readonly property bool charging: ServiceBattery.isCharging && !thresholdActive
    readonly property bool low: discharging && percent <= 20
    readonly property var profiles: ServiceBattery.availableProfiles
    readonly property string activeProfile: ServiceBattery.powerProfile

    readonly property bool opened: ServicePanel.activePanel === root
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
        return available ? ServiceBattery.batteryIcon : "";
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
        ServiceBattery.setPowerProfile(profile);
    }

    onOpenedChanged: if (opened) {
        phraseIndex = 0;
        selectedProfileIndex = Math.max(0,
            profiles.findIndex(profile => String(profile) === activeProfile));
    }
    onAvailableChanged: if (!available)
        ServicePanel.close(root)

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

    PanelStatusRotator {
        target: batteryHero.statusLabel
        running: root.opened && root.activePhrases.length > 0
        onAdvance: {
            if (root.activePhrases.length > 0)
                root.phraseIndex = (root.phraseIndex + 1) % root.activePhrases.length;
        }
    }

    BarButton {
        id: label
        anchors.centerIn: parent
        panel: root
        text: root.batteryIcon()
        textColor: root.low ? Theme.urgent : Theme.foreground
        onClicked: ServicePanel.toggle(root)
    }

    HyprlandFocusGrab {
        active: root.opened
        windows: [panel, root.QsWindow.window]
        onCleared: ServicePanel.close(root)
    }

    PanelPopup {
        id: panel
        anchorItem: root
        anchorWindow: root.QsWindow.window
        visible: root.opened
        onCloseRequested: ServicePanel.close(root)
        borderColor: Theme.border
        contentSpacing: 14
        // Wider card gives each equal-width profile button real horizontal
        // breathing room around its icon and longest label (Power-saver).
        implicitWidth: 420
        implicitHeight: panelContent.implicitHeight
            + contentTopMargin + contentBottomMargin

        PanelHero {
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
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Util.scaledFont(30)
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
                color: Util.alpha(Theme.foreground, 0.12)
            }
            Rectangle {
                anchors.left: chargeTrack.left
                anchors.verticalCenter: chargeTrack.verticalCenter
                height: chargeTrack.height
                width: Math.max(height, chargeTrack.width * root.fraction)
                radius: height / 2
                color: Theme.foreground
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
                    valueText: ServiceBattery.batterySizeWh > 0
                        ? Math.round(ServiceBattery.batterySizeWh) + "Wh" : "—"
                }
                InfoPair {
                    labelText: "Charge cycles"
                    valueText: ServiceBattery.chargeCycles >= 0
                        ? String(ServiceBattery.chargeCycles) : "—"
                }
            }
            Column {
                width: (batteryMetrics.width - batteryMetrics.spacing) / 2
                spacing: 12
                InfoPair {
                    labelText: root.thresholdActive ? "Charge limit"
                        : (root.discharging ? "Time left" : "Time to full")
                    valueText: root.thresholdActive ? (ServiceBattery.chargeThreshold || "—")
                        : (root.fullyCharged ? "—"
                            : ServiceBattery.formatDuration(ServiceBattery.secondsRemaining))
                }
                InfoPair {
                    labelText: root.thresholdActive ? "Battery state"
                        : (root.discharging ? "Discharging" : "Charging")
                    valueText: root.thresholdActive ? "Holding"
                        : (root.fullyCharged ? "—"
                            : (ServiceBattery.changeRate > 0
                                ? ServiceBattery.changeRate.toFixed(1).replace(/\\.0$/, "") + "W" : "—"))
                }
            }
        }

        PanelSeparator {}

        Column {
            width: parent.width
            spacing: 10

            PanelSectionHeader {
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
                    PanelOptionButton {
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
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: Util.scaledFont(15)
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: String(profileButton.modelData) === "PowerSaver"
                                    ? "Power-saver" : String(profileButton.modelData)
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: Util.scaledFont(12)
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
            color: Theme.foreground
            opacity: 0.6
            font.family: Theme.fontFamily
            font.pixelSize: Util.scaledFont(12)
        }
        Item {
            width: Math.max(0, parent.width
                - parent.children[0].implicitWidth - parent.children[2].implicitWidth - 16)
            height: 1
        }
        Text {
            text: parent.valueText
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Util.scaledFont(12)
        }
    }
}
