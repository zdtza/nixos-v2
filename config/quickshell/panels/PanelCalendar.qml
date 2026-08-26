pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Stylix
import "../components"
import "../services"
import ".."

// Current-year calendar shown from clock in bar.
PanelPopup {
    id: root

    property int shownMonth: clock.date.getMonth()
    property string selectedDay: ""
    property string selectedRangeEnd: ""
    property int keyboardDayIndex: 0

    readonly property real weekColumnWidth: 44
    readonly property real dayColumnWidth: (panelContent.width - weekColumnWidth) / 7
    readonly property var monthNames: [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
    readonly property var weekdayNames: ["W", "MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
    readonly property int currentYear: clock.date.getFullYear()
    readonly property var keyboardDays: cells.filter(cell => !cell.weekNumber)
    readonly property int selectedDayCount: {
        if (!selectedDay || !selectedRangeEnd) return 0;
        const start = selectedDay.split("-").map(Number);
        const end = selectedRangeEnd.split("-").map(Number);
        const startTime = Date.UTC(start[0], start[1] - 1, start[2]);
        const endTime = Date.UTC(end[0], end[1] - 1, end[2]);
        return Math.round(Math.abs(endTime - startTime) / 86400000) + 1;
    }
    readonly property int yearCompletePercent: {
        const start = new Date(root.currentYear, 0, 1);
        const end = new Date(root.currentYear + 1, 0, 1);
        const fraction = (clock.date.getTime() - start.getTime()) / (end.getTime() - start.getTime());
        return Math.round(Math.max(0, Math.min(1, fraction)) * 100);
    }
    readonly property var cells: {
        // Touch clock.date so model rolls over automatically at midnight.
        const today = clock.date;
        const first = new Date(root.currentYear, root.shownMonth, 1, 12);
        const mondayOffset = (first.getDay() + 6) % 7;
        const firstVisible = new Date(root.currentYear, root.shownMonth, 1 - mondayOffset, 12);
        const values = [];

        for (let week = 0; week < 6; ++week) {
            const weekStart = new Date(firstVisible);
            weekStart.setDate(firstVisible.getDate() + week * 7);
            values.push({ weekNumber: true, label: root.isoWeek(weekStart) });

            for (let day = 0; day < 7; ++day) {
                const date = new Date(weekStart);
                date.setDate(weekStart.getDate() + day);
                values.push({
                    weekNumber: false,
                    label: date.getDate(),
                    key: root.dateKey(date.getFullYear(), date.getMonth(), date.getDate()),
                    inYear: date.getFullYear() === root.currentYear,
                    inMonth: date.getMonth() === root.shownMonth,
                    today: date.getFullYear() === today.getFullYear()
                        && date.getMonth() === today.getMonth()
                        && date.getDate() === today.getDate()
                });
            }
        }

        return values;
    }

    function dateKey(year: int, month: int, day: int): string {
        return year + "-" + String(month + 1).padStart(2, "0")
            + "-" + String(day).padStart(2, "0");
    }

    function selectDay(key: string, extendSelection: bool): void {
        if (extendSelection) {
            if (!root.selectedDay) {
                root.selectedDay = key;
                root.selectedRangeEnd = "";
            } else {
                root.selectedRangeEnd = key === root.selectedDay ? "" : key;
            }
            return;
        }

        // Plain-clicking anywhere in a range clears it. Clicking elsewhere
        // moves anchor there; clicking a single selected day clears it.
        if (root.selectedRangeEnd && root.daySelected(key)) {
            root.selectedDay = "";
            root.selectedRangeEnd = "";
            return;
        }
        const wasSingleSelection = !root.selectedRangeEnd && root.selectedDay === key;
        root.selectedDay = wasSingleSelection ? "" : key;
        root.selectedRangeEnd = "";
    }

    function daySelected(key: string): bool {
        if (!root.selectedDay || !key) return false;
        if (!root.selectedRangeEnd) return key === root.selectedDay;
        const first = root.selectedDay < root.selectedRangeEnd
            ? root.selectedDay : root.selectedRangeEnd;
        const last = root.selectedDay < root.selectedRangeEnd
            ? root.selectedRangeEnd : root.selectedDay;
        return key >= first && key <= last;
    }

    function rangeEndpoint(key: string): bool {
        return key === root.selectedDay
            || (!!root.selectedRangeEnd && key === root.selectedRangeEnd);
    }

    function isoWeek(date: var): int {
        const utc = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
        const day = utc.getUTCDay() || 7;
        utc.setUTCDate(utc.getUTCDate() + 4 - day);
        const yearStart = new Date(Date.UTC(utc.getUTCFullYear(), 0, 1));
        return Math.ceil((((utc - yearStart) / 86400000) + 1) / 7);
    }

    function changeMonth(offset: int): void {
        const current = keyboardDays[keyboardDayIndex];
        const currentParts = current ? current.key.split("-").map(Number) : [];
        const preferredDay = currentParts.length === 3
            && currentParts[1] - 1 === shownMonth ? currentParts[2] : 1;
        shownMonth = (shownMonth + offset + 12) % 12;
        const lastDay = new Date(currentYear, shownMonth + 1, 0).getDate();
        const targetKey = dateKey(currentYear, shownMonth,
            Math.min(preferredDay, lastDay));
        const targetIndex = keyboardDays.findIndex(day => day.key === targetKey);
        if (targetIndex >= 0)
            keyboardDayIndex = targetIndex;
    }

    function moveKeyboardDay(offset: int): void {
        if (keyboardDays.length === 0)
            return;
        keyboardDayIndex = Math.max(0,
            Math.min(keyboardDays.length - 1, keyboardDayIndex + offset));
    }

    function activateKeyboardDay(extendSelection: bool): void {
        if (keyboardDays[keyboardDayIndex])
            selectDay(keyboardDays[keyboardDayIndex].key, extendSelection);
    }

    onVisibleChanged: {
        if (!visible) {
            clearSelection();
            return;
        }
        const todayKey = dateKey(clock.date.getFullYear(), clock.date.getMonth(), clock.date.getDate());
        keyboardDayIndex = Math.max(0,
            keyboardDays.findIndex(day => day.key === todayKey));
    }
    onBackgroundClicked: clearSelection()

    function clearSelection(): void {
        selectedDay = "";
        selectedRangeEnd = "";
    }

    contentHorizontalMargins: 80
    contentTopMargin: 18
    contentSpacing: 16
    implicitWidth: 650
    implicitHeight: panelContent.implicitHeight
        + contentTopMargin + contentBottomMargin

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Shortcut {
        enabled: root.visible
        sequence: "Shift+Left"
        context: Qt.ApplicationShortcut
        onActivated: root.changeMonth(-1)
    }
    Shortcut {
        enabled: root.visible
        sequence: "Shift+Right"
        context: Qt.ApplicationShortcut
        onActivated: root.changeMonth(1)
    }
    Shortcut {
        enabled: root.visible
        sequence: "Left"
        context: Qt.ApplicationShortcut
        onActivated: root.moveKeyboardDay(-1)
    }
    Shortcut {
        enabled: root.visible
        sequence: "Right"
        context: Qt.ApplicationShortcut
        onActivated: root.moveKeyboardDay(1)
    }
    Shortcut {
        enabled: root.visible
        sequence: "Up"
        context: Qt.ApplicationShortcut
        onActivated: root.moveKeyboardDay(-7)
    }
    Shortcut {
        enabled: root.visible
        sequence: "Down"
        context: Qt.ApplicationShortcut
        onActivated: root.moveKeyboardDay(7)
    }
    Shortcut {
        enabled: root.visible
        sequence: "Return"
        context: Qt.ApplicationShortcut
        onActivated: root.activateKeyboardDay(false)
    }
    Shortcut {
        enabled: root.visible
        sequence: "Enter"
        context: Qt.ApplicationShortcut
        onActivated: root.activateKeyboardDay(false)
    }
    Shortcut {
        enabled: root.visible
        sequence: "Shift+Return"
        context: Qt.ApplicationShortcut
        onActivated: root.activateKeyboardDay(true)
    }
    Shortcut {
        enabled: root.visible
        sequence: "Shift+Enter"
        context: Qt.ApplicationShortcut
        onActivated: root.activateKeyboardDay(true)
    }
    Shortcut {
        enabled: root.visible
        sequence: "Delete"
        context: Qt.ApplicationShortcut
        onActivated: root.clearSelection()
    }

    Item {
        width: root.panelContent.width
        implicitHeight: 50

        Row {
            anchors.centerIn: parent
            spacing: 24

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰃭"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Utils.scaledFont(50)
                font.bold: true
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.monthNames[clock.date.getMonth()] + " " + clock.date.getDate()
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Utils.scaledFont(48)
                font.weight: Font.Bold
            }
        }
    }

    Row {
        x: 17
        width: root.panelContent.width - 38
        height: 40
        spacing: 8

        Text {
            width: 44
            anchors.verticalCenter: parent.verticalCenter
            text: root.currentYear
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: Utils.scaledFont(12)
            font.letterSpacing: 1
        }

        Item {
            width: parent.width - 44 - 42 - parent.spacing * 2
            height: 8
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.fill: parent
                radius: ServicePanel.rounding
                color: Theme.surface
            }

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * root.yearCompletePercent / 100
                radius: ServicePanel.rounding
                color: Theme.foreground
            }
        }

        Text {
            width: 42
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: root.yearCompletePercent + "%"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Utils.scaledFont(12)
            font.letterSpacing: 1
        }
    }

    Row {
        width: root.panelContent.width
        height: 18

        Repeater {
            model: root.weekdayNames

            Text {
                required property string modelData
                required property int index

                width: index === 0 ? root.weekColumnWidth : root.dayColumnWidth
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Utils.scaledFont(11)
                font.weight: Font.Medium
                font.letterSpacing: 1
            }
        }
    }

    Item {
        width: root.panelContent.width
        implicitHeight: calendarGrid.implicitHeight

        Grid {
            id: calendarGrid

            width: parent.width
            columns: 8
            rowSpacing: 3

            Repeater {
                model: root.cells

                Item {
                    id: dayCell

                    required property var modelData
                    required property int index

                    readonly property bool marked: !modelData.weekNumber
                        && root.daySelected(modelData.key)
                    readonly property bool rangeEndpoint: !modelData.weekNumber
                        && root.rangeEndpoint(modelData.key)
                    readonly property bool keyboardSelected: !modelData.weekNumber
                        && root.keyboardDays[root.keyboardDayIndex]?.key === modelData.key

                    width: index % 8 === 0 ? root.weekColumnWidth : root.dayColumnWidth
                    height: 42

                    Rectangle {
                        anchors.centerIn: parent
                        width: dayCell.modelData.weekNumber ? 0 : root.dayColumnWidth - 8
                        height: 36
                        radius: ServicePanel.rounding
                        visible: !dayCell.modelData.weekNumber
                            && (dayCell.marked || dayCell.modelData.today
                                || dayCell.keyboardSelected)
                        color: dayCell.marked || dayCell.keyboardSelected
                            ? Theme.surface : "transparent"
                        border.width: dayCell.rangeEndpoint || dayCell.modelData.today
                            || dayCell.keyboardSelected ? 1 : 0
                        border.color: dayCell.rangeEndpoint ? Theme.muted : Theme.border
                    }

                    Text {
                        anchors.centerIn: parent
                        text: dayCell.modelData.label
                        color: dayCell.modelData.weekNumber || !dayCell.modelData.inMonth
                            ? Theme.border : Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Utils.scaledFont(dayCell.modelData.weekNumber ? 10 : 13)
                        font.weight: dayCell.marked ? Font.Medium : Font.Normal
                    }

                    MouseArea {
                        id: dayMouse

                        anchors.fill: parent
                        enabled: !dayCell.modelData.weekNumber
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onContainsMouseChanged: if (containsMouse) {
                            const index = root.keyboardDays.findIndex(day =>
                                day.key === dayCell.modelData.key);
                            if (index >= 0)
                                root.keyboardDayIndex = index;
                        }
                        onClicked: mouse => root.selectDay(dayCell.modelData.key,
                            (mouse.modifiers & Qt.ShiftModifier) !== 0)
                    }
                }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: root.weekColumnWidth - 1
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            color: Theme.border
            opacity: 0.45
        }
    }

    Item {
        width: root.panelContent.width
        implicitHeight: 42

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 28
            color: "transparent"

            Text {
                anchors.fill: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: "‹"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Utils.scaledFont(18)
            }

            MouseArea {
                id: previousMouse

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.changeMonth(-1)
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 2

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: (root.monthNames[root.shownMonth] + " " + root.currentYear).toUpperCase()
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Utils.scaledFont(11)
                font.weight: Font.Medium
                font.letterSpacing: 1.4
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.selectedDayCount > 0
                text: root.selectedDayCount + " DAYS SELECTED"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Utils.scaledFont(9)
                font.letterSpacing: 1
            }
        }

        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 28
            color: "transparent"

            Text {
                anchors.fill: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: "›"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Utils.scaledFont(18)
            }

            MouseArea {
                id: nextMouse

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.changeMonth(1)
            }
        }
    }
}
