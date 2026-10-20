// Quick toggles: active ones stay visible as indicators, inactive ones slide
// out while the toggles' own area is hovered.
import QtQuick
import Quickshell
import "../../services"

Item {
    id: root

    property var timerPanel: null
    property var nightLightPanel: null
    // This bar's monitor, which shows the recording indicator while captured.
    property string screenName: ""
    // Placed after the clock, so the row grows away from it towards the end.
    property bool mirrored: false
    property bool expanded: false

    // Never narrower than one icon cell, so there is always a strip to hover even with every toggle off.
    implicitWidth: Math.max(PanelService.barIconWidth, toggles.implicitWidth)
    implicitHeight: PanelService.barItemHeight

    // Collapses after a short grace period, so brushing past the edge does not snap them shut.
    HoverHandler {
        onHoveredChanged: {
            if (hovered) {
                collapseTimer.stop();
                root.expanded = true;
            } else {
                collapseTimer.restart();
            }
        }
    }

    Timer {
        id: collapseTimer
        interval: 250
        onTriggered: root.expanded = false
    }

    // Anchored to the clock side, with the clock-most slots kept nearest it.
    Row {
        id: toggles

        anchors.right: root.mirrored ? undefined : parent.right
        anchors.left: root.mirrored ? parent.left : undefined
        layoutDirection: root.mirrored ? Qt.RightToLeft : Qt.LeftToRight
        anchors.verticalCenter: parent.verticalCenter

        QuickToggleSlot {
            gapBefore: !root.mirrored
            shown: StayAwakeService.active || root.expanded

            QuickToggleButton {
                icon: "󰅶"
                active: StayAwakeService.active
                inactiveColor: Theme.textMuted
                onClicked: StayAwakeService.toggle()
            }
        }

        QuickToggleSlot {
            gapBefore: !root.mirrored
            shown: DoNotDisturbService.active || root.expanded

            QuickToggleButton {
                icon: "󰂛"
                active: DoNotDisturbService.active
                inactiveColor: Theme.textMuted
                onClicked: DoNotDisturbService.toggle()
            }
        }

        QuickToggleSlot {
            gapBefore: !root.mirrored
            shown: NightLightService.active || root.expanded

            QuickToggleButton {
                icon: "󰖔"
                active: NightLightService.active
                inactiveColor: Theme.textMuted
                onClicked: PanelService.toggle(root.nightLightPanel)
            }
        }

        // The countdown itself shows on the clock's right.
        QuickToggleSlot {
            gapBefore: !root.mirrored
            shown: TimerService.running || root.expanded

            QuickToggleButton {
                icon: "󱎫"
                active: TimerService.running
                inactiveColor: Theme.textMuted
                onClicked: PanelService.toggle(root.timerPanel)
            }
        }

        // Recording or screen sharing of this monitor, from any app. Clicking
        // stops a screen-record recording; other apps' shares end in the app.
        QuickToggleSlot {
            gapBefore: !root.mirrored
            shown: ScreencastService.recordedMonitors.includes(root.screenName)

            QuickToggleButton {
                icon: "\ueba7"
                active: true
                activeColor: Theme.base08
                onClicked: Quickshell.execDetached(["screen-record", "--stop"])
            }
        }
    }
}
