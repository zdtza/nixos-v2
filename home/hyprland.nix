{ config, ... }:

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
}
