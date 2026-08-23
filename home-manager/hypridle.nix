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

  showCursor = pkgs.writeShellScript "tte-screensaver-show-cursor" ''
    ${pkgs.hyprland}/bin/hyprctl dispatch \
      '(function() hl.config({ cursor = { invisible = false } }); return hl.dsp.no_op() end)()' \
      >/dev/null
  '';

  screensaver = pkgs.writeShellScriptBin "tte-screensaver" ''
    monitor_data="$(${pkgs.hyprland}/bin/hyprctl monitors -j)"
    monitors="$(printf '%s' "$monitor_data" | ${pkgs.jq}/bin/jq -r '.[].name')"
    monitor_count="$(printf '%s' "$monitor_data" | ${pkgs.jq}/bin/jq 'length')"
    [ -n "$monitors" ] || exit 0

    set_cursor_invisible() {
      ${pkgs.hyprland}/bin/hyprctl dispatch \
        "(function() hl.config({ cursor = { invisible = $1 } }); return hl.dsp.no_op() end)()" \
        >/dev/null
    }
    trap '${showCursor}' EXIT

    kitty_pids=""
    for monitor in $monitors; do
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
    done

    # Hide cursor only after every output's window has mapped. This readiness
    # poll does not gate launches or compositor-side monitor assignment.
    for _ in $(${pkgs.coreutils}/bin/seq 1 100); do
      mapped_count="$(${pkgs.hyprland}/bin/hyprctl clients -j \
        | ${pkgs.jq}/bin/jq '[.[] | select(.class == "tte-screensaver")] | length')"
      if [ "$mapped_count" -ge "$monitor_count" ]; then
        set_cursor_invisible true
        break
      fi
      ${pkgs.coreutils}/bin/sleep 0.02
    done

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
      ExecStopPost = "${showCursor}";
      KillMode = "control-group";
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
