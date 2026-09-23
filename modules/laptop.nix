# battery/suspend/bluetooth tuning, only makes sense on a laptop.
{ pkgs, ... }:
{
  boot.kernelParams = [ "mem_sleep_default=deep" ];

  services = {
    logind.settings.Login = {
    HandlePowerKey = "suspend-then-hibernate";
    HandleLidSwitch = "suspend-then-hibernate";
    HandleLidSwitchExternalPower = "suspend-then-hibernate";
  };

    upower = {
    enable = true;
    # Shut down cleanly at critical battery level.
    criticalPowerAction = "PowerOff";
    percentageLow = 15;
    percentageCritical = 5;
    percentageAction = 3;
  };

    tlp = {
    enable = true;
    # exposing tlp via power-profiles d-bus, so quickshell can switch profiles.
    pd.enable = true;
    settings = {
      # TLP 1.10 defaults battery operation to its Balanced profile even though
      # the _BAT settings are power-conscious. Select Power Saver explicitly so
      # tlp-pd (and therefore Quickshell) reports and applies that profile.
      TLP_AUTO_SWITCH = 1;
      TLP_PROFILE_AC = "PRF";
      TLP_PROFILE_BAT = "SAV";
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      CPU_MIN_PERF_ON_AC = 0;
      CPU_MAX_PERF_ON_AC = 100;
      CPU_MIN_PERF_ON_BAT = 0;
      CPU_MAX_PERF_ON_BAT = 60; # Battery/Power Saver cap; Performance uses ON_AC.
    };
    };
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  systemd = {
    sleep.settings.Sleep = {
      HibernateDelaySec = "3h";
      HibernateOnACPower = true;
    };

    # Clear rfkill's persisted soft block before bluetoothd starts.
    services.bluetooth-unblock = {
    description = "Unblock Bluetooth rfkill before bluetoothd starts";
    wantedBy = [ "multi-user.target" ];
    before = [ "bluetooth.service" ];
    after = [ "systemd-rfkill.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.util-linux}/bin/rfkill unblock bluetooth";
    };
    };
  };
}
