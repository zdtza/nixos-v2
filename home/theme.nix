# Theme selection lives entirely in home-manager (not NixOS), so switching
# is `sw` (see home/shell.nix's fish function) -- no sudo, no nixos-rebuild.
# stylix.base16Scheme/image set here as a plain option beat the NixOS
# module's own values, which stylix forwards down as mkDefault (see
# stylix's home-manager-integration.nix), so this cleanly wins.
{ lib, config, ... }:
let
  themes = import ./themes/list.nix;
in
{
  options.theme.name = lib.mkOption {
    type = lib.types.enum (builtins.attrNames themes);
    default = "tokyo-night";
    description = "Selected preset from home/themes/list.nix.";
  };

  config.stylix = {
    base16Scheme = themes.${config.theme.name}.colors;
    image = themes.${config.theme.name}.wallpaper;
  };
}
