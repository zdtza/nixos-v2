{
  pkgs,
  lib,
  config,
  ...
}:

{
  # enabling stylix hyprpaper config
  services.hyprpaper.enable = true;
  # targeting all monitors with stylix defined wallpaper
  stylix.targets.hyprpaper.monitor = "";

  # don't draw the wallpaper until quickshell has actually grabbed the
  # session lock: hyprpaper is small/fast and can otherwise win the race
  # against quickshell's heavier QML startup, flashing the desktop under
  # the not-yet-drawn lock screen on cold boot.
  systemd.user.services.hyprpaper = {
    Unit = {
      After = [ "quickshell.service" ];
      # home-manager's hyprpaper module defaults to restarting the service
      # whenever hyprpaper.conf's content changes (X-Restart-Triggers), which
      # is every `sw` since it embeds the theme-hashed wallpaper store path.
      # hyprpaper has a live wallpaper-swap IPC for exactly this (see
      # home.activation.hyprpaperReload below) -- use that instead of a full
      # stop/start, which also re-runs the wait-for-lock guard above for no
      # reason on a switch that isn't a real login.
      X-Restart-Triggers = lib.mkForce [ ];
    };
    Service.ExecStartPre = lib.getExe (
      pkgs.writeShellScriptBin "hyprpaper-wait-for-lock" ''
        for _ in $(seq 1 50); do
          [ "$(${pkgs.quickshell}/bin/qs ipc call lock isLocked 2>/dev/null)" = "true" ] && exit 0
          sleep 0.1
        done
      ''
    );
  };

  # push the new wallpaper into the already-running daemon instead of
  # restarting it. This hyprpaper (0.8.4, rewritten hyprwire IPC) dropped the
  # classic preload/unload requests -- "invalid hyprpaper request" -- a
  # single `wallpaper "monitor,path"` request now loads and swaps in one go.
  # The empty-monitor catch-all form (",path", matching stylix's monitor = ""
  # above) is accepted but silently a no-op on a monitor that already has a
  # wallpaper assigned -- only re-applying by the monitor's actual name
  # swaps it, so loop over whatever `listactive` reports instead.
  home.activation.hyprpaperReload = lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
    hyprctl="${lib.getExe' pkgs.hyprland "hyprctl"}"
    while IFS=: read -r monitor _; do
      [ -n "$monitor" ] && run "$hyprctl" hyprpaper wallpaper "$monitor,${config.stylix.image}" 2>/dev/null
    done < <("$hyprctl" hyprpaper listactive 2>/dev/null)
  '';
}
