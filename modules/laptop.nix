# battery/suspend/bluetooth tuning, only makes sense on a laptop
{ pkgs, ... }:
{
  boot.kernelParams = [ "mem_sleep_default=deep" ];

  # power button suspends instead of the systemd default (poweroff)
  services.logind.settings.Login.HandlePowerKey = "suspend";

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

      # ponytail: unconfirmed fix, TLP's default runtime PM (auto) can race
      # with nvidia's own suspend/resume hooks and leave the GPU asleep on
      # wake; testing exclusion. Revert if tlp-stat -e no longer shows
      # nvidia stuck in D3 after a bad wake, or if it doesn't fix it.
      RUNTIME_PM_DRIVER_DENYLIST = "nvidia";
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
