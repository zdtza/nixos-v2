{ pkgs, ... }:

let
  resumeCommand = pkgs.writeShellScript "hypridle-resume" ''
    ${pkgs.hyprland}/bin/hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })'

    # The listeners which caused sleep remain fired until there is input.
    ${pkgs.systemd}/bin/systemctl --user --no-block restart hypridle.service
  '';

  configFile = pkgs.writeText "hypridle.conf" ''
    general {
        ignore_dbus_inhibit = false
        ignore_systemd_inhibit = false
        before_sleep_cmd = ${pkgs.quickshell}/bin/qs ipc call lock activate
        after_sleep_cmd = ${resumeCommand}
    }

    listener {
        timeout = 300
        on-timeout = ${pkgs.hyprland}/bin/hyprctl dispatch 'hl.dsp.dpms({ action = "disable" })'
        on-resume = ${pkgs.hyprland}/bin/hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })'
    }

    listener {
        timeout = 1800
        on-timeout = ${pkgs.systemd}/bin/systemctl suspend-then-hibernate
    }
  '';
in
{
  home.packages = [
    pkgs.hypridle
  ];

  systemd.user.services = {
  # Caffeine blocks idle actions only.
    stay-awake = {
    Unit = {
      Description = "Inhibit idle actions while caffeine mode is enabled";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.systemd}/bin/systemd-inhibit --what=idle --mode=block --who=Quickshell --why=Stay-awake ${pkgs.coreutils}/bin/sleep infinity";
      KillMode = "control-group";
    };
  };

    hypridle = {
    Unit = {
      Description = "Hyprland idle manager";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "${pkgs.hypridle}/bin/hypridle --config ${configFile}";
      Restart = "on-failure";
      RestartSec = 2;
    };

    Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
