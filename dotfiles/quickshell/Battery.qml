pragma ComponentBehavior: Bound

// Omarchy-style power panel backed by UPower and TLP's power-profile API.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Stylix

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

    readonly property var chargingPhrases: ["Pumping power", "Injecting electrons", "Pouring juice", "Amassing watts", "Hoarding joules", "Sucking volts", "Topping reserves", "Soaking amps", "Inhaling kilowatts"]
    readonly property var batteryPhrases: ["Slurping power", "Spending joules", "Draining watts", "Burning electrons", "Sipping juice", "Spending coulombs", "Bleeding amps", "Guzzling volts", "Munching reserves"]
    readonly property var activePhrases: charging ? chargingPhrases : (discharging ? batteryPhrases : [])
    readonly property string statusText: fullyCharged ? "Fully charged" : thresholdActive ? "Threshold" : activePhrases.length > 0 ? activePhrases[phraseIndex % activePhrases.length] : "Battery"

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
        text: BatteryService.showPercentage ? root.percent + "% " + root.batteryIcon() : root.batteryIcon()
        textColor: root.low ? Theme.urgent : Theme.foreground
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                BatteryService.togglePercentage();
            else
                PanelService.toggle(root);
        }
    }

    HyprlandFocusGrab {
        active: root.opened
        windows: [panel, root.QsWindow.window]
        onCleared: PanelService.close(root)
    }

    PanelPopup {
        id: panel
        anchorItem: root
        anchorWindow: root.QsWindow.window
        visible: root.opened
        onCloseRequested: PanelService.close(root)
        borderColor: Theme.border
        contentSpacing: 14
        // Wider card gives each equal-width profile button real horizontal
        // breathing room around its icon and longest label (Power-saver).
        implicitWidth: 420
        implicitHeight: panelContent.implicitHeight + contentMargins * 2

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
                font.pixelSize: 30
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
                color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.12)
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
            width: parent.width
            spacing: 28

            Column {
                width: (parent.width - 20) / 2
                spacing: 12
                InfoPair {
                    labelText: "Battery size"
                    valueText: BatteryService.batterySizeWh > 0 ? Math.round(BatteryService.batterySizeWh) + "Wh" : "—"
                }
                InfoPair {
                    labelText: "Charge cycles"
                    valueText: BatteryService.chargeCycles >= 0 ? String(BatteryService.chargeCycles) : "—"
                }
            }
            Column {
                width: (parent.width - 20) / 2
                spacing: 12
                InfoPair {
                    labelText: root.thresholdActive ? "Charge limit" : (root.discharging ? "Time left" : "Time to full")
                    valueText: root.thresholdActive ? (BatteryService.chargeThreshold || "—") : (root.fullyCharged ? "—" : BatteryService.formatDuration(BatteryService.secondsRemaining))
                }
                InfoPair {
                    labelText: root.thresholdActive ? "Battery state" : (root.discharging ? "Discharging" : "Charging")
                    valueText: root.thresholdActive ? "Holding" : (root.fullyCharged ? "—" : (BatteryService.changeRate > 0 ? BatteryService.changeRate.toFixed(1).replace(/\\.0$/, "") + "W" : "—"))
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
                readonly property real cellWidth: root.profiles.length > 0 ? (width - spacing * (root.profiles.length - 1)) / root.profiles.length : 0

                Repeater {
                    model: root.profiles
                    Rectangle {
                        id: profileButton
                        required property var modelData
                        required property int index
                        width: profileRow.cellWidth
                        height: 36
                        color: profileMouse.pressed ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.22) : root.activeProfile === String(modelData) ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.18) : profileButton.index === root.selectedProfileIndex || profileMouse.containsMouse ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.08) : Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.04)
                        border.width: 1
                        border.color: profileButton.index === root.selectedProfileIndex || profileMouse.containsMouse ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.25) : Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.4)
                        radius: 0
                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.profileIcon(String(profileButton.modelData))
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 15
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: String(profileButton.modelData) === "PowerSaver" ? "Power-saver" : String(profileButton.modelData)
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.bold: root.activeProfile === String(profileButton.modelData)
                            }
                        }

                        MouseArea {
                            id: profileMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.selectedProfileIndex = profileButton.index;
                                root.setProfile(String(profileButton.modelData));
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
            font.pixelSize: 12
        }
        Item {
            width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth - 16)
            height: 1
        }
        Text {
            text: parent.valueText
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }
    }
}
