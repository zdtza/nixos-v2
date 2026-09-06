{ pkgs, lib, ... }:

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
    Unit.After = [ "quickshell.service" ];
    Service.ExecStartPre = lib.getExe (
      pkgs.writeShellScriptBin "hyprpaper-wait-for-lock" ''
        for _ in $(seq 1 50); do
          [ "$(${pkgs.quickshell}/bin/qs ipc call lock isLocked 2>/dev/null)" = "true" ] && exit 0
          sleep 0.1
        done
      ''
    );
  };
}
