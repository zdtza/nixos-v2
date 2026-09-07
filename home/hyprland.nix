{ config, lib, pkgs, ... }:

let
  # raw (no '#') hex, hyprland colors want 0xAARRGGBB
  colors = config.lib.stylix.colors;
in
{
  # symlinking the hyprland lua config, single file for maximum portability
  home.file.".config/hypr/hyprland.lua".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.src/nixos/config/hypr/hyprland.lua";

  # stylix bridge for hyprland.lua: unlike the quickshell qml module this is
  # required by a lua file that lives out-of-store, so the colors have to
  # land as a small generated module next to it instead of inline strings.
  home.file.".config/hypr/stylix.lua".text = ''
    return {
        active_border = "0xff${colors.base0D}",
        inactive_border = "0xff${colors.base01}",
    }
  '';

  # `hyprctl reload` re-executes hyprland.lua's `require("stylix")` fresh
  # (verified: not a cached, long-lived Lua module table) -- without this,
  # `sw` swaps stylix.lua's symlink target but nothing ever tells the
  # running Hyprland session to re-read it, so border colors only changed on
  # the next full Hyprland restart. Best-effort: no session, no failure.
  home.activation.hyprReload = lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
    if [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
      run ${lib.getExe' pkgs.hyprland "hyprctl"} reload || true
    fi
  '';
}
