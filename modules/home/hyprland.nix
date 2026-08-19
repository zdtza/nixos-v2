{ ... }:

{
  flake.homeModules.hyprland =
    { config, pkgs, ... }:
    {
      xdg.configFile."hypr".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Nix/.config/hypr";
    };
}
