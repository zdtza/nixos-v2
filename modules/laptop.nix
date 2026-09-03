# battery/suspend/bluetooth tuning, only makes sense on a laptop
{ pkgs, ... }:
{
  boot.kernelParams = [ "mem_sleep_default=deep" ];

  # power-saver on battery, performance when plugged in
  services.upower = {
    enable = true;
    # default HybridSleep needs a resume device this host doesn't have and fails
    # silently, power off cleanly at the critical level instead
    criticalPowerAction = "PowerOff";
    percentageLow = 15;
    percentageCritical = 5;
    percentageAction = 3;
  };

  services.tlp = {
    enable = true;
    # exposing tlp via power-profiles d-bus, so quickshell can switch profiles
    pd.enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      CPU_MIN_PERF_ON_AC = 0;
      CPU_MAX_PERF_ON_AC = 100;
      CPU_MIN_PERF_ON_BAT = 0;
      CPU_MAX_PERF_ON_BAT = 60; # Lower cap to save power on battery
    };
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # force-unblocking bluetooth before bluetoothd starts, systemd-rfkill can
  # persist a soft-blocked state across rebuilds/reboots
  systemd.services.bluetooth-unblock = {
    description = "Unblock Bluetooth rfkill before bluetoothd starts";
    wantedBy = [ "multi-user.target" ];
    before = [ "bluetooth.service" ];
    after = [ "systemd-rfkill.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.util-linux}/bin/rfkill unblock bluetooth";
    };
  };
}
