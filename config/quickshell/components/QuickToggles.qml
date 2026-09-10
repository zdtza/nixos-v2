// Optional controls in the bar's right-hand group. Inactive controls collapse
// to nothing and appear when the reserved area is hovered; active ones stay
// visible. Order is fixed (see the Row below) -- a slot never moves, whether
// it is active, inactive or collapsed, so the same control is always in the
// same place.
import QtQuick
import "../panels"
import "../services"

Item {
    id: root

    readonly property bool expanded: hover.hovered || nightLightToggle.opened
        || timerToggle.opened
    readonly property var nightLightPanel: nightLightToggle
    readonly property var timerPanel: timerToggle

    // Reserve hover space for every toggle, including collapsed controls, so
    // entering anywhere the expanded tray occupies reveals the full tray.
    implicitWidth: 28 * 4
    implicitHeight: 26

    HoverHandler {
        id: hover
    }

    // Right-anchored: collapsed slots take no width, so the visible controls
    // always sit against the right edge of the reserved strip. Declaration
    // order here *is* the on-screen order, left to right -- night light and
    // timer last, i.e. outermost right; swap those two lines to flip them.
    Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        QuickToggleSlot {
            shown: root.expanded || StayAwakeService.enabled

            QuickToggleButton {
                icon: "󰅶"
                active: StayAwakeService.enabled
                onClicked: StayAwakeService.toggle()
            }
        }

        QuickToggleSlot {
            shown: root.expanded || DoNotDisturbService.enabled

            QuickToggleButton {
                icon: "󰂛"
                active: DoNotDisturbService.enabled
                onClicked: DoNotDisturbService.toggle()
            }
        }

        QuickToggleSlot {
            // Running state is already surfaced by the badge next to the
            // clock, so this slot only reveals on hover rather than staying
            // pinned open while a timer counts down.
            shown: root.expanded

            TimerTogglePanel { id: timerToggle }
        }

        QuickToggleSlot {
            shown: root.expanded || NightLightService.enabled

            NightLightTogglePanel { id: nightLightToggle }
        }
    }
}
