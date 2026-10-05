{ pkgs, ... }:

let
  restoreDisplaysCommand = pkgs.writeShellScript "hypridle-restore-displays" ''
    ${pkgs.hyprland}/bin/hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })'

    # A blanket DPMS enable must not restore the closed laptop panel to the
    # compositor layout, but only when an external monitor remains: disabling
    # the sole output leaves the compositor with none. Monitor configuration is
    # Lua state, not a dispatcher.
    if ${pkgs.gnugrep}/bin/grep -q closed /proc/acpi/button/lid/*/state \
      && ${pkgs.hyprland}/bin/hyprctl monitors -j | ${pkgs.jq}/bin/jq -e 'any(.[]; .name != "eDP-1")' >/dev/null; then
      ${pkgs.hyprland}/bin/hyprctl eval 'hl.monitor({ output = "eDP-1", disabled = true })'
    fi
  '';

  resumeCommand = pkgs.writeShellScript "hypridle-resume" ''
    ${restoreDisplaysCommand}

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
        on-resume = ${restoreDisplaysCommand}
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
    # Caffeine blocks idle timeout actions only; lid handling is unconditional.
    stay-awake = {
      Unit = {
        Description = "Inhibit idle timeout actions while caffeine mode is enabled";
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
