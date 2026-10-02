{ config, lib, ... }:

let
  # Active windows use a muted gray; inactive borders blend into the background.
  activeBorderColor = config.lib.stylix.colors.withHashtag.base04;
  inactiveBorderColor = config.lib.stylix.colors.withHashtag.base00;
  activeHyprColor = lib.removePrefix "#" activeBorderColor;
  inactiveHyprColor = lib.removePrefix "#" inactiveBorderColor;
in
{
  home.file = {
    # Keep the hand-written Hyprland configuration directly editable.
    ".config/hypr/hyprland.lua".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.src/nixos/config/hypr/hyprland.lua";

    # Bridge the selected Stylix theme into the Lua configuration.
    ".config/hypr/stylix.lua".text = ''
      return {
        active_border_color = "rgb(${activeHyprColor})",
        inactive_border_color = "rgb(${inactiveHyprColor})",
      }
    '';
  };
}
