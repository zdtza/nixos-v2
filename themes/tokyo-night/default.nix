{
  # Active wallpaper, rewritten by scripts/select-wallpaper.sh (and by the
  # quickshell picker, which shells out to it) -- always a file in ./wallpapers.
  wallpaper = ./wallpapers/1-quattro.jpg;
  colors = {
    base00 = "#1a1b26"; # background
    base01 = "#13141c"; # dark_background
    base02 = "#292e42"; # selection
    base03 = "#414868"; # muted
    base04 = "#565f89"; # dark_foreground
    base05 = "#a9b1d6"; # foreground
    base06 = "#b4bee6"; # light_foreground
    base07 = "#c0caf5"; # bright_foreground
    base08 = "#f7768e"; # red
    base09 = "#eb927b"; # orange
    base0A = "#e0af68"; # yellow
    base0B = "#9ece6a"; # green
    base0C = "#4dbfd0"; # cyan
    base0D = "#7aa2f7"; # blue
    base0E = "#ad8ee6"; # magenta
    base0F = "#75493d"; # brown
  };
  # neovim mapping style borrowed from ~/omarchy/themes/*/neovim.lua
  neovim = {
    plugin = "https://github.com/folke/tokyonight.nvim";
    colorscheme = "tokyonight-night";
    lualine = "tokyonight";
  };
  # workbench.colorTheme label, from the installed extension's
  # package.json (contributes.themes[].label) -- see home/vscode.nix
  vscode = "Tokyo Night";
  # org.gnome.desktop.interface accent-color (see home/appearance.nix):
  # one of libadwaita's fixed enum names (blue/teal/green/yellow/orange/
  # red/pink/purple/slate), nearest to base0D above. The one part of a
  # GTK4/libadwaita app's palette that re-renders live in an
  # already-running process (AdwStyleManager watches it) -- everything
  # else in gtk.css is a CSS provider compiled once at startup.
  gtkAccent = "blue";
  # pkgs.yaru-theme variant, folder/mime icons recolored per accent (see
  # home/appearance.nix). Names are fixed by the package: Yaru-{blue,magenta,
  # olive,prussiangreen,purple,red,sage,wartybrown,yellow}, each with a -dark
  # twin. Borrowed from ~/omarchy/themes/*/icons.theme.
  iconTheme = "Yaru-magenta";
}
