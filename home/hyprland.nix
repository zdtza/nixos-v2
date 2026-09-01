{ config, ... }:

{
  # live symlink into the repo: edit + `hyprctl reload`, no rebuild needed
  home.file.".config/hypr/hyprland.lua".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.src/nixos/config/hypr/hyprland.lua";

  # enabling stylix hyprpaper config
  services.hyprpaper.enable = true;
  stylix.targets.hyprpaper.monitor = "";
}
