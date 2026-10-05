{
  config,
  pkgs,
  lib,
  ...
}:

let
  # Shared Satty editor for screenshots and imv.
  sattyEdit = pkgs.writeShellScriptBin "satty-edit" ''
    exec ${lib.getExe pkgs.satty} \
      --filename "$1" \
      --output-filename "$1" \
      --copy-command ${lib.getExe' pkgs.wl-clipboard "wl-copy"} \
      --early-exit all
  '';

  # Capture a region, copy it, and offer annotation.
  screenshot = pkgs.writeShellScriptBin "screenshot" ''
    set -euo pipefail
    export PATH=${
      lib.makeBinPath [
        pkgs.grim
        pkgs.slurp
        pkgs.wayfreeze
        pkgs.wl-clipboard
        pkgs.libnotify
        pkgs.coreutils
        sattyEdit
      ]
    }:$PATH

    dir="${config.home.homeDirectory}/Screenshots"
    mkdir -p "$dir"

    # Freeze a copy of the desktop before showing the region selector. This keeps
    # transient UI in place, and the EXIT trap always restores the live desktop
    # when slurp is cancelled or this script is interrupted.
    freeze_pid=""
    cleanup() {
      if [ -n "$freeze_pid" ]; then
        kill "$freeze_pid" 2>/dev/null || true
        wait "$freeze_pid" 2>/dev/null || true
      fi
    }
    trap cleanup EXIT

    wayfreeze --hide-cursor &
    freeze_pid=$!
    sleep 0.1

    # slurp exits non-zero on escape, causing the EXIT trap to unfreeze the screen.
    region=$(slurp)
    file="$dir/screenshot-$(date +%Y%m%d-%H%M%S).png"

    grim -g "$region" "$file"
    cleanup
    freeze_pid=""
    trap - EXIT

    wl-copy --type image/png <"$file"

    action=$(notify-send --app-name=Screenshot --action=default=Edit -t 4000 \
      "Screenshot saved" "$(basename "$file")")

    [ "$action" = default ] || exit 0
    satty-edit "$file"
  '';
in
{
  home.packages = [
    screenshot
    sattyEdit
  ];

  # Open images in imv and annotate them with Ctrl+E.
  xdg.configFile."imv/config".text = ''
    [binds]
    <Ctrl+e> = exec satty-edit "$imv_current_file" & ; quit
  '';
}
