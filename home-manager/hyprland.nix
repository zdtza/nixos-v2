{ self, ... }:

{
  # referencing self does not have real time symlink, need to rebuild to apply hyprland changes
  # copy hyprland lua to config folder for active real-time development
  home.file.".config/hypr/hyprland.lua".source = self + "/dotfiles/hypr/hyprland.lua";

  # enabling stylix hyprpaper config
  services.hyprpaper.enable = true;
  stylix.targets.hyprpaper.monitor = "";
}
