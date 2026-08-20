{ self, ... }:

{
  home.file.".config/hypr/hyprland.lua".source = self + "/dotfiles/hypr/hyprland.lua";
  home.file.".config/hypr/config".source = self + "/dotfiles/hypr/config";

  # enabling stylix hyprpaper config
  services.hyprpaper.enable = true;
  stylix.targets.hyprpaper.monitor = "";
}
