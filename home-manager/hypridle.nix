{ pkgs, ... }:

let
  package = pkgs.hypridle;

  # Matrix rain fills the terminal, then resolves to this text when its rain
  # phase completes.
  matrixInput = pkgs.writeText "tte-screensaver-input" ''
    ███╗   ██╗ ██╗ ██╗  ██╗  ██████╗  ███████╗
    ████╗  ██║ ██║ ╚██╗██╔╝ ██╔═══██╗ ██╔════╝
    ██╔██╗ ██║ ██║  ╚███╔╝  ██║   ██║ ███████╗
    ██║╚██╗██║ ██║  ██╔██╗  ██║   ██║ ╚════██║
    ██║ ╚████║ ██║ ██╔╝ ██╗ ╚██████╔╝ ███████║
    ╚═╝  ╚═══╝ ╚═╝ ╚═╝  ╚═╝  ╚═════╝  ╚══════╝
  '';

  # Opening a fullscreen window itself resets Hyprland's idle notifier. Start a
  # fresh notifier after Kitty maps so only subsequent user input dismisses it.
  dismissConfig = pkgs.writeText "tte-screensaver-dismiss.conf" ''
    general {
        ignore_dbus_inhibit = true
    }

    listener {
        timeout = 1
        on-timeout = ${pkgs.coreutils}/bin/true
        on-resume = ${pkgs.systemd}/bin/systemctl --user stop --no-block tte-screensaver.service
    }
  '';

  screensaver = pkgs.writeShellScriptBin "tte-screensaver" ''
    monitor_data="$(${pkgs.hyprland}/bin/hyprctl monitors -j)"
    monitors="$(printf '%s' "$monitor_data" | ${pkgs.jq}/bin/jq -r '.[].name')"
    focused_monitor="$(printf '%s' "$monitor_data" | ${pkgs.jq}/bin/jq -r '.[] | select(.focused).name')"
    [ -n "$monitors" ] || exit 0

    restore_focus() {
      [ -n "$focused_monitor" ] || return
      focused_monitor_lua="$(printf '%s' "$focused_monitor" | ${pkgs.jq}/bin/jq -Rs .)"
      ${pkgs.hyprland}/bin/hyprctl dispatch \
        "hl.dsp.focus({ monitor = $focused_monitor_lua })" >/dev/null
    }
    trap restore_focus EXIT

    kitty_pids=""
    for monitor in $monitors; do
      # Windows initially map on focused output. Focus each output before
      # launching its instance; this also works with Hyprland's Lua dispatchers.
      monitor_lua="$(printf '%s' "$monitor" | ${pkgs.jq}/bin/jq -Rs .)"
      ${pkgs.hyprland}/bin/hyprctl dispatch \
        "hl.dsp.focus({ monitor = $monitor_lua })" >/dev/null

      window_title="tte-screensaver-$monitor"
      ${pkgs.kitty}/bin/kitty \
        --class tte-screensaver \
        --title "$window_title" \
        --override background=#000000 \
        --override background_opacity=1 \
        --override font_size=14 \
        --override window_padding_width=0 \
        ${pkgs.terminaltexteffects}/bin/tte \
          --input-file ${matrixInput} \
          --terminal-background-color 000000 \
          --canvas-width 0 \
          --canvas-height 0 \
          --anchor-text c \
          --frame-rate 60 \
          matrix \
          --highlight-color dbffdb \
          --rain-color-gradient 92be92 185318 \
          --rain-fall-delay-range 1-15 \
          --rain-column-delay-range 6-18 \
          --rain-time 600 \
          --symbol-swap-chance 0.005 \
          --color-swap-chance 0.001 &
      kitty_pid=$!
      kitty_pids="$kitty_pids $kitty_pid"

      # Keep output focused until its window maps, then continue to next one.
      for _ in $(${pkgs.coreutils}/bin/seq 1 50); do
        if ${pkgs.hyprland}/bin/hyprctl clients -j \
          | ${pkgs.jq}/bin/jq -e --arg title "$window_title" \
            'any(.[]; .title == $title)' >/dev/null; then
          break
        fi
        ${pkgs.coreutils}/bin/sleep 0.1
      done
    done

    restore_focus
    trap - EXIT

    # Let Kitty's synthetic resume events pass before arming dismissal.
    ${pkgs.coreutils}/bin/sleep 1
    ${package}/bin/hypridle --config ${dismissConfig} &

    wait $kitty_pids
  '';

  configFile = pkgs.writeText "hypridle.conf" ''
    general {
        ignore_dbus_inhibit = false
        before_sleep_cmd = ${pkgs.quickshell}/bin/qs ipc call lock activate
        after_sleep_cmd = ${pkgs.hyprland}/bin/hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })'
    }

    listener {
        timeout = 300
        on-timeout = ${pkgs.systemd}/bin/systemctl --user start tte-screensaver.service
    }

    listener {
        timeout = 600
        on-timeout = ${pkgs.systemd}/bin/systemctl --user stop tte-screensaver.service; ${pkgs.hyprland}/bin/hyprctl dispatch 'hl.dsp.dpms({ action = "disable" })'
        on-resume = ${pkgs.hyprland}/bin/hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })'
    }

    listener {
        timeout = 1800
        on-timeout = ${pkgs.systemd}/bin/systemctl suspend
    }
  '';
in
{
  home.packages = [
    package
    screensaver
  ];

  # Started and stopped by hypridle; not enabled at session startup.
  systemd.user.services.tte-screensaver = {
    Unit = {
      Description = "Terminal Text Effects Matrix screensaver";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "${screensaver}/bin/tte-screensaver";
      KillMode = "control-group";
      CPUQuota = "25%";
    };
  };

  systemd.user.services.hypridle = {
    Unit = {
      Description = "Hyprland idle manager";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "${package}/bin/hypridle --config ${configFile}";
      Restart = "on-failure";
      RestartSec = 2;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
