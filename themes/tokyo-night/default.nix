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
  vscode = "Tokyo Night";
  # base16 slot used as this theme's accent: yazi's folder icons/border and
  # hyprland's active window border (home/yazi.nix, home/hyprland.nix)
  accent = "base0D";
  gtkAccent = "blue";
  iconTheme = "Yaru-magenta";
}
