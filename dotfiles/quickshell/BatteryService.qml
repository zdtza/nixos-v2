pragma Singleton

// Shared battery and power-profile state. PowerProfiles talks to TLP through
// tlp-pd's power-profiles-daemon compatible D-Bus API.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Item {
    id: root

    readonly property bool showPercentage: persisted.showPercentage
    readonly property var battery: UPower.displayDevice
    readonly property var physicalBattery: findPhysicalBattery()
    readonly property bool available: !!(battery && battery.ready && battery.isPresent)
    readonly property string batteryPath: physicalBattery ? `/sys/class/power_supply/${physicalBattery.nativePath}` : ""
    readonly property real fraction: available ? Math.max(0, Math.min(1, Number(battery.percentage || 0))) : 0
    readonly property int chargePercent: Math.round(fraction * 100)
    readonly property real batterySizeWh: available ? Number(battery.energyCapacity || 0) : 0
    readonly property int chargeCycles: fileNumber(cycleCountFile)
    readonly property bool isDischarging: available && UPower.onBattery
    readonly property bool isCharging: available && !UPower.onBattery && battery.state === UPowerDeviceState.Charging
    readonly property bool fullyCharged: available && battery.state === UPowerDeviceState.FullyCharged && fraction >= 0.99
    readonly property string batteryState: available ? UPowerDeviceState.toString(battery.state) : "Unknown"
    readonly property string powerProfile: PowerProfile.toString(PowerProfiles.profile)
    readonly property var availableProfiles: PowerProfiles.hasPerformanceProfile
        ? ["PowerSaver", "Balanced", "Performance"]
        : ["PowerSaver", "Balanced"]
    readonly property string chargeThreshold: thresholdLabel()
    readonly property real changeRate: available ? Number(battery.changeRate || 0) : 0
    readonly property real secondsRemaining: isDischarging
        ? Number(battery.timeToEmpty || 0)
        : Number(battery.timeToFull || 0)

    readonly property bool thresholdActive: available && !UPower.onBattery
        && (battery.state === UPowerDeviceState.PendingCharge
            || (battery.state === UPowerDeviceState.FullyCharged && fraction < 0.99)
            || (battery.state === UPowerDeviceState.Charging && fraction < 0.99
                && (changeRate <= 0.2 || Number(battery.timeToFull || 0) >= 28800)))

    readonly property string batteryIcon: {
        if (!available) return "󰁹";
        const chargingIcons = ["󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"];
        const batteryIcons = ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"];
        const index = Math.max(0, Math.min(9, Math.floor(fraction * 10)));
        if (thresholdActive) return batteryIcons[index];
        if (fullyCharged) return "󰂅";
        return isDischarging ? batteryIcons[index] : chargingIcons[index];
    }

    function findPhysicalBattery(): var {
        for (const device of UPower.devices.values) {
            if (device.isLaptopBattery && device.nativePath !== "")
                return device;
        }
        return null;
    }

    function fileNumber(file: FileView): int {
        if (!file.loaded) return -1;
        const value = Number(file.text().trim());
        return Number.isFinite(value) ? value : -1;
    }

    function thresholdLabel(): string {
        const start = fileNumber(thresholdStartFile);
        const end = fileNumber(thresholdEndFile);
        if (end < 0) return "";
        return start >= 0 && start !== end ? `${start}-${end}%` : `${end}%`;
    }

    function formatDuration(seconds: real): string {
        if (!Number.isFinite(seconds) || seconds <= 0) return "—";
        const totalMinutes = Math.round(seconds / 60);
        const hours = Math.floor(totalMinutes / 60);
        const minutes = totalMinutes % 60;
        if (hours <= 0) return `${minutes}m`;
        return minutes > 0 ? `${hours}h ${minutes}m` : `${hours}h`;
    }

    function togglePercentage(): void {
        persisted.showPercentage = !persisted.showPercentage;
    }

    function setPowerProfile(profile: string): bool {
        switch (profile) {
        case "PowerSaver":
            PowerProfiles.profile = PowerProfile.PowerSaver;
            return true;
        case "Balanced":
            PowerProfiles.profile = PowerProfile.Balanced;
            return true;
        case "Performance":
            if (!PowerProfiles.hasPerformanceProfile) return false;
            PowerProfiles.profile = PowerProfile.Performance;
            return true;
        default:
            console.warn("Unknown power profile:", profile);
            return false;
        }
    }

    function refreshSupplementalInfo(): void {
        cycleCountFile.reload();
        thresholdStartFile.reload();
        thresholdEndFile.reload();
    }

    PersistentProperties {
        id: persisted
        reloadableId: "quickshell-battery"
        property bool showPercentage: false
    }

    FileView {
        id: cycleCountFile
        path: root.batteryPath === "" ? "" : `${root.batteryPath}/cycle_count`
        preload: true
        watchChanges: true
        printErrors: false
    }
    FileView {
        id: thresholdStartFile
        path: root.batteryPath === "" ? "" : `${root.batteryPath}/charge_control_start_threshold`
        preload: true
        watchChanges: true
        printErrors: false
    }
    FileView {
        id: thresholdEndFile
        path: root.batteryPath === "" ? "" : `${root.batteryPath}/charge_control_end_threshold`
        preload: true
        watchChanges: true
        printErrors: false
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshSupplementalInfo()
    }

    Connections {
        target: UPower
        function onOnBatteryChanged(): void { root.refreshSupplementalInfo(); }
    }
}
