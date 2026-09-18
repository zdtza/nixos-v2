{ config, pkgs, lib, ... }:

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
        pkgs.wl-clipboard
        pkgs.libnotify
        pkgs.coreutils
        sattyEdit
      ]
    }:$PATH

    dir="${config.home.homeDirectory}/Screenshots"
    mkdir -p "$dir"

    # slurp exits non-zero on escape, set -e aborts here before anything is written.
    region=$(slurp)
    file="$dir/screenshot-$(date +%Y%m%d-%H%M%S).png"

    grim -g "$region" "$file"
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
