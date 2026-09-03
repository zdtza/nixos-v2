{ config, ... }:

{
  # symlinking the hyprland lua config, single file for maximum portability
  home.file.".config/hypr/hyprland.lua".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.src/nixos/config/hypr/hyprland.lua";
}
