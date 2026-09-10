{ config, pkgs, lib, ... }:

let
  # Single definition of "open this image in satty", shared by the screenshot
  # notification and imv's Ctrl+E bind so their flags can't drift apart.
  # Saves over the original and re-copies to the clipboard, then exits.
  sattyEdit = pkgs.writeShellScriptBin "satty-edit" ''
    exec ${lib.getExe pkgs.satty} \
      --filename "$1" \
      --output-filename "$1" \
      --copy-command ${lib.getExe' pkgs.wl-clipboard "wl-copy"} \
      --early-exit all
  '';

  # region -> file + clipboard, then a notification whose "default" action
  # (left click, see config/quickshell/components/Notifications.qml) reopens
  # the shot in satty. notify-send --action blocks until the action fires or
  # the card expires, so this script outlives the capture -- fine, hyprland's
  # exec_cmd already detached it.
  screenshot = pkgs.writeShellScriptBin "screenshot" ''
    set -euo pipefail
    export PATH=${
      lib.makeBinPath [
        pkgs.grim
        pkgs.slurp
        pkgs.wl-clipboard
        pkgs.libnotify
        pkgs.coreutils
        sattyEdit
      ]
    }:$PATH

    dir="${config.home.homeDirectory}/Screenshots"
    mkdir -p "$dir"

    # slurp exits non-zero on escape, set -e aborts here before anything is written
    region=$(slurp)
    file="$dir/screenshot-$(date +%Y%m%d-%H%M%S).png"

    grim -g "$region" "$file"
    wl-copy --type image/png <"$file"

    action=$(notify-send --app-name=Screenshot --action=default=Edit -t 3000 \
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

  # satty.desktop ships NoDisplay=true (it is a file handler, not a launchable
  # app -- it refuses to start without --filename), so the launcher skips it
  # (Launcher.qml drops noDisplay entries). imv is the default image handler,
  # this makes it the way in: open any image, Ctrl+E to annotate.
  xdg.configFile."imv/config".text = ''
    [binds]
    <Ctrl+e> = exec satty-edit "$imv_current_file" & ; quit
  '';
}
