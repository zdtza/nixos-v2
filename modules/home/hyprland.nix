{ config, lib, ... }:

{
  home.file = {
    # Keep the hand-written Hyprland configuration directly editable.
    ".config/hypr/hyprland.lua".source =
      config.lib.file.mkOutOfStoreSymlink "${config.repoPath}/config/hypr/hyprland.lua";
  };
}
