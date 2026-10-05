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

  hypridleConf = ''
    general {
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
  # Run by the hypridle service in modules/home/services.nix.
  xdg.configFile."hypr/hypridle.conf".text = hypridleConf;
}
