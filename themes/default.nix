# Every theme lives in its own folder next to this file:
#
#   themes/<name>/default.nix   colors, neovim/vscode mappings, active wallpaper
#   themes/<name>/wallpapers/   the set components/WallpaperPicker.qml offers
#   themes/<name>/preview.png   still unused; for a future theme picker
#
# Folder name *is* the theme name (theme.name in home/appearance.nix, and what
# scripts/select-theme.sh writes). Adding a theme is adding a folder -- the
# readDir below picks it up, there is no list to keep in sync.
#
# Plain data, no lib/config args, so it can be `import`-ed standalone by
# scripts/select-theme.sh, home/nvim.nix, home/vscode.nix, home/quickshell.nix,
# home/appearance.nix (which wires it into stylix and declares theme.name --
# see that file), and modules/wayland.nix (a NixOS module, outside
# home-manager's module tree).
let
  entries = builtins.readDir ./.;
  names = builtins.filter (name: entries.${name} == "directory") (builtins.attrNames entries);
in
{
  themes = builtins.listToAttrs (map (name: {
    inherit name;
    value = import (./. + "/${name}");
  }) names);
}
