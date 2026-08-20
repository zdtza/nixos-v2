{ config, ... }:

{
  # symlinking files to actual config path
  home.file.".config/hypr/hyprland.lua".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/symlink/hypr/hyprland.lua";
  home.file.".config/hypr/config".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/symlink/hypr/config";

  # enabling stylix hyprpaper config
  services.hyprpaper.enable = true;
  stylix.targets.hyprpaper.monitor = "";
}
