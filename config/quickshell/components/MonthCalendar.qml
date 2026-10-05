// Compact month view used by the clock panel.
import QtQuick
import Quickshell
import "../services"
import ".."

Item {
    id: root

    readonly property int cellHeight: 34
    property date visibleMonth: new Date()
    readonly property date today: calendarClock.date
    readonly property int firstDayOffset: {
        const first = new Date(visibleMonth.getFullYear(), visibleMonth.getMonth(), 1);
        // Keep the week Monday-first, matching the shell's day-month date format.
        return (first.getDay() + 6) % 7;
    }

    implicitHeight: calendarColumn.implicitHeight

    function resetToToday(): void {
        visibleMonth = new Date(today.getFullYear(), today.getMonth(), 1);
    }

    function moveMonth(offset: int): void {
        visibleMonth = new Date(visibleMonth.getFullYear(),
            visibleMonth.getMonth() + offset, 1);
    }

    function dateAt(index: int): var {
        return new Date(visibleMonth.getFullYear(), visibleMonth.getMonth(),
            index - firstDayOffset + 1);
    }

    function isToday(value: var): bool {
        return value.getFullYear() === today.getFullYear()
            && value.getMonth() === today.getMonth()
            && value.getDate() === today.getDate();
    }

    SystemClock {
        id: calendarClock
        precision: SystemClock.Minutes
    }

    Component.onCompleted: resetToToday()

    Column {
        id: calendarColumn
        width: parent.width
        spacing: 8

        Item {
            width: parent.width
            height: 32

            ShellText {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDate(root.visibleMonth, "MMMM yyyy")
                size: 14
                font.bold: true
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Repeater {
                    model: [
                        { label: "‹", offset: -1 },
                        { label: "›", offset: 1 }
                    ]

                    Rectangle {
                        required property var modelData

                        width: 32
                        height: 28
                        radius: PanelService.rounding
                        color: monthMouse.pressed
                            ? Utils.alpha(Theme.base05, 0.2)
                            : monthMouse.containsMouse
                                ? Utils.alpha(Theme.base05, 0.12)
                                : "transparent"

                        ShellText {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -1
                            text: parent.modelData.label
                            size: 19
                        }

                        MouseArea {
                            id: monthMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.moveMonth(parent.modelData.offset)
                        }
                    }
                }
            }
        }

        Row {
            width: parent.width
            height: 18

            Repeater {
                model: ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

                ShellText {
                    required property string modelData

                    width: root.width / 7
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: Theme.textSecondary
                    size: 10
                    font.bold: true
                }
            }
        }

        Grid {
            width: parent.width
            height: root.cellHeight * 6
            columns: 7

            Repeater {
                model: 42

                Item {
                    id: dayCell

                    required property int index
                    readonly property var value: root.dateAt(index)
                    readonly property bool inMonth: value.getMonth()
                        === root.visibleMonth.getMonth()
                    readonly property bool currentDay: root.isToday(value)

                    width: root.width / 7
                    height: root.cellHeight

                    HoverHandler { id: dayHover }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 30
                        height: 30
                        radius: PanelService.rounding
                        color: dayHover.hovered
                            ? Utils.alpha(Theme.base05, 0.12)
                            : dayCell.currentDay
                                ? Utils.alpha(Theme.base05, 0.18) : "transparent"
                        border.width: dayCell.currentDay || dayHover.hovered ? 1 : 0
                        border.color: dayCell.currentDay
                            ? Utils.alpha(Theme.base05, 0.8)
                            : Utils.alpha(Theme.base05, 0.3)

                        ShellText {
                            anchors.centerIn: parent
                            text: dayCell.value.getDate()
                            color: dayCell.inMonth
                                ? Theme.textPrimary : Theme.textMuted
                            size: 12
                            font.bold: dayCell.currentDay
                        }
                    }
                }
            }
        }
    }
}
