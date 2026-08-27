# Battery/suspend/bluetooth tuning that only makes sense on a laptop. Don't
# import into a desktop or server host.
{ pkgs, ... }:
{
  boot.kernelParams = [ "mem_sleep_default=deep" ];

  # power-saver on battery, performance when plugged in
  services.upower.enable = true;

  services.tlp = {
    enable = true;
    # Expose TLP through the power-profiles D-Bus API. This keeps TLP as
    # the single power manager while allowing Quickshell's native
    # PowerProfiles service to select performance, balanced, and
    # power-saver profiles.
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

  # systemd-rfkill can persist a previous soft-blocked Bluetooth state.
  # Force-unblock the controller before bluetoothd starts so powerOnBoot
  # can reliably turn it on after rebuilds/reboots.
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
