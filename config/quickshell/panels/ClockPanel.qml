pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "../components"
import "../services"
import ".."

// Configurable list of local and remote clocks.
Drawer {
    id: root

    property bool addingZone: false
    property string addError: ""
    property var zoneTimes: ({})

    // Common time-zone abbreviations resolve to geographic zones so daylight
    // saving changes continue to be applied automatically.
    readonly property var timeCodes: ({
        "UTC": "UTC",
        "GMT": "Etc/GMT",
        "EST": "America/New_York",
        "EDT": "America/New_York",
        "CST": "America/Chicago",
        "CDT": "America/Chicago",
        "MST": "America/Denver",
        "MDT": "America/Denver",
        "PST": "America/Los_Angeles",
        "PDT": "America/Los_Angeles",
        "AKST": "America/Anchorage",
        "AKDT": "America/Anchorage",
        "HST": "Pacific/Honolulu",
        "AST": "America/Halifax",
        "ADT": "America/Halifax",
        "NST": "America/St_Johns",
        "NDT": "America/St_Johns",
        "BST": "Europe/London",
        "WET": "Europe/Lisbon",
        "WEST": "Europe/Lisbon",
        "CET": "Europe/Paris",
        "CEST": "Europe/Paris",
        "EET": "Europe/Helsinki",
        "EEST": "Europe/Helsinki",
        "IST": "Asia/Kolkata",
        "JST": "Asia/Tokyo",
        "KST": "Asia/Seoul",
        "HKT": "Asia/Hong_Kong",
        "SGT": "Asia/Singapore",
        "WIB": "Asia/Jakarta",
        "WITA": "Asia/Makassar",
        "WIT": "Asia/Jayapura",
        "AEST": "Australia/Sydney",
        "AEDT": "Australia/Sydney",
        "ACST": "Australia/Adelaide",
        "ACDT": "Australia/Adelaide",
        "AWST": "Australia/Perth",
        "NZST": "Pacific/Auckland",
        "NZDT": "Pacific/Auckland",
        "WAT": "Africa/Lagos",
        "CAT": "Africa/Harare",
        "EAT": "Africa/Nairobi",
        "SAST": "Africa/Johannesburg"
    })

    readonly property int zoneRowHeight: 108
    readonly property int zoneRowSpacing: 14
    readonly property real maximumHeight: Math.max(320,
        (anchorWindow && anchorWindow.screen ? anchorWindow.screen.height : 800) - 55)
    readonly property real desiredZoneHeight: ClockService.timeZones.length * zoneRowHeight
        + Math.max(0, ClockService.timeZones.length - 1) * zoneRowSpacing
    readonly property real zoneViewportHeight: Math.min(470, desiredZoneHeight)

    contentSpacing: 14
    closeOnEscape: !addingZone
    implicitWidth: 420
    implicitHeight: Math.min(maximumHeight,
        contentTopMargin + contentBottomMargin + clockHero.implicitHeight + 1
            + zoneViewportHeight + contentSpacing * 2
            + (addingZone ? 46 + contentSpacing : 0))

    function displayName(zone: string): string {
        return zone.length === 0 ? "Local time" : zone.replace(/_/g, " ");
    }

    function zoneTime(zone: string): var {
        return zoneTimes[zone] ?? { time: "--:--:--", date: "", abbreviation: "" };
    }

    function toggleAdd(): void {
        addingZone = !addingZone;
        addError = "";
        if (addingZone) {
            zoneInput.text = "";
            Qt.callLater(() => zoneInput.forceActiveFocus());
        }
    }

    function submitZone(): void {
        const code = zoneInput.text.trim().toUpperCase();
        if (code.length === 0)
            return;

        const zone = timeCodes[code] ?? "";
        if (zone.length === 0) {
            addError = "Unknown code";
            return;
        }
        if (ClockService.timeZones.indexOf(zone) !== -1) {
            addError = "Already added";
            return;
        }

        ClockService.addTimeZone(zone);
        addingZone = false;
        addError = "";
        zoneInput.text = "";
    }

    function refreshTimes(): void {
        if (!open || timeProcess.running)
            return;

        const args = ClockService.timeZones.map(zone => zone.length === 0 ? "@local" : zone);
        timeProcess.command = ["sh", "-c", timeProcess.script, "sh"].concat(args);
        timeProcess.running = true;
    }

    onOpenChanged: {
        if (open) {
            refreshTimes();
        } else {
            addingZone = false;
            addError = "";
        }
    }

    Connections {
        target: ClockService
        function onTimeZonesChanged(): void { root.refreshTimes(); }
    }

    SystemClock {
        enabled: root.open
        precision: SystemClock.Seconds
        onDateChanged: root.refreshTimes()
    }

    Process {
        id: timeProcess

        readonly property string script: `
# Format one captured instant in every zone so the displayed seconds cannot
# straddle a second boundary while this loop runs.
now=$(date +%s)
for zone do
    if [ "$zone" = @local ]; then
        unset TZ
        key=
    else
        TZ=$zone
        export TZ
        key=$zone
    fi
    printf '%s\\t' "$key"
    date --date="@$now" '+%H:%M:%S%t%A, %d %b %Y%t%Z'
done
`

        stdout: StdioCollector {
            onStreamFinished: {
                const values = {};
                for (const line of text.split("\n")) {
                    if (line.length === 0)
                        continue;
                    const fields = line.split("\t");
                    if (fields.length < 4)
                        continue;
                    values[fields[0]] = {
                        time: fields[1],
                        date: fields[2],
                        abbreviation: fields[3]
                    };
                }
                root.zoneTimes = values;
            }
        }
    }

    Hero {
        id: clockHero
        width: parent.width
        icon: "󰥔"
        title: "Clock"
        status: ClockService.timeZones.length === 1
            ? "LOCAL TIME"
            : String(ClockService.timeZones.length) + " TIME ZONES"
        trailingWidth: 32
        trailingHeight: 28

        Rectangle {
            anchors.fill: parent
            radius: PanelService.rounding
            color: addMouse.containsMouse
                ? Utils.alpha(Theme.base05, 0.12)
                : "transparent"
            border.width: 1
            border.color: Utils.alpha(Theme.base05, 0.3)

            ShellText {
                anchors.centerIn: parent
                text: root.addingZone ? "󰅖" : "󰐕"
                size: 14
            }

            MouseArea {
                id: addMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleAdd()
            }
        }
    }

    Separator {}

    Rectangle {
        width: parent.width
        height: 46
        visible: root.addingZone
        radius: PanelService.rounding
        color: Theme.base01
        border.width: 1
        border.color: root.addError.length > 0
            ? Theme.base08
            : (zoneInput.activeFocus ? Theme.base04
                : Utils.alpha(Theme.base05, 0.3))

        ShellText {
            anchors {
                left: parent.left
                leftMargin: 12
                verticalCenter: parent.verticalCenter
            }
            visible: zoneInput.text.length === 0
            text: "Time code, e.g. PST or CET"
            color: Theme.base04
            size: 12
        }

        TextInput {
            id: zoneInput
            anchors {
                fill: parent
                leftMargin: 12
                rightMargin: 100
            }
            verticalAlignment: TextInput.AlignVCenter
            activeFocusOnPress: true
            selectByMouse: true
            color: Theme.base05
            selectionColor: Theme.base02
            selectedTextColor: Theme.base05
            font.family: Theme.monospace
            font.pixelSize: Utils.scaledFont(12)

            onTextEdited: root.addError = ""
            Keys.onReturnPressed: root.submitZone()
            Keys.onEnterPressed: root.submitZone()
            Keys.onEscapePressed: root.toggleAdd()
        }

        ShellText {
            anchors {
                right: parent.right
                rightMargin: 12
                verticalCenter: parent.verticalCenter
            }
            visible: root.addError.length > 0
            text: root.addError
            color: Theme.base08
            size: 10
        }
    }

    Item {
        width: parent.width
        height: root.zoneViewportHeight
        clip: true

        Flickable {
            id: zoneList
            anchors.fill: parent
            contentHeight: zoneColumn.implicitHeight
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            clip: true

            Column {
                id: zoneColumn
                width: parent.width
                spacing: root.zoneRowSpacing

                Repeater {
                    model: ClockService.timeZones

                    Item {
                        id: zoneRow

                        required property string modelData
                        required property int index
                        readonly property string zone: modelData
                        readonly property var current: root.zoneTime(zone)
                        readonly property bool showActions: zone.length > 0
                            && zoneHover.hovered

                        width: zoneColumn.width
                        // Give local time a little more breathing room while
                        // avoiding excess space below the final entry.
                        height: root.zoneRowHeight
                            + (zone.length === 0 ? 4 : 0)
                            - (index === ClockService.timeZones.length - 1 ? 4 : 0)

                        HoverHandler { id: zoneHover }

                        SectionHeader {
                            width: parent.width
                            title: root.displayName(zoneRow.zone).toUpperCase()
                            detail: zoneRow.showActions
                                ? "" : zoneRow.current.abbreviation
                        }

                        Column {
                            id: clockColumn

                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                topMargin: 24
                            }
                            spacing: 4

                            ShellText {
                                id: timeLabel
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: zoneRow.current.time
                                size: 30
                                font.weight: Font.Medium
                            }

                            ShellText {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: zoneRow.current.date
                                opacity: 0.8
                                size: 20
                                font.weight: Font.Medium
                            }
                        }

                        RowActionButton {
                            id: deleteButton
                            z: 2
                            visible: zoneRow.showActions
                            anchors {
                                top: parent.top
                                right: parent.right
                                rightMargin: 2
                            }
                            icon: "󰆴"
                            onClicked: ClockService.removeTimeZone(zoneRow.zone)
                        }

                        RowActionButton {
                            id: moveDownButton
                            z: 2
                            // The first remote clock moves down; every clock
                            // beneath it exposes the complementary move-up action.
                            visible: zoneRow.index === 1
                                && ClockService.timeZones.length > 2
                                && zoneRow.showActions
                            anchors {
                                top: parent.top
                                right: deleteButton.left
                                rightMargin: 6
                            }
                            icon: "󰁅"
                            onClicked: ClockService.moveTimeZone(
                                zoneRow.index, zoneRow.index + 1)
                        }

                        RowActionButton {
                            z: 2
                            visible: zoneRow.index > 1 && zoneRow.showActions
                            anchors {
                                top: parent.top
                                right: moveDownButton.visible
                                    ? moveDownButton.left : deleteButton.left
                                rightMargin: 6
                            }
                            icon: "󰁝"
                            onClicked: ClockService.moveTimeZone(
                                zoneRow.index, zoneRow.index - 1)
                        }

                        Separator {
                            visible: zoneRow.index < ClockService.timeZones.length - 1
                            anchors.bottom: parent.bottom
                        }
                    }
                }
            }
        }
    }
}
