# Generated from ~/omarchy/themes/everforest (colors.toml, neovim.lua, vscode.json).
{
  wallpaper = ./wallpapers/1-tree-tops.jpg;
  polarity = "dark";
  colors = {
    base00 = "#2d353b"; # background
    base01 = "#21272c"; # dark_background
    base02 = "#3d484d"; # selection
    base03 = "#475258"; # muted
    base04 = "#4f585e"; # dark_foreground
    base05 = "#d3c6aa"; # foreground
    base06 = "#9da9a0"; # light_foreground
    base07 = "#d3c6aa"; # bright_foreground
    base08 = "#e67e80"; # red
    base09 = "#e09d7f"; # orange
    base0A = "#dbbc7f"; # yellow
    base0B = "#a7c080"; # green
    base0C = "#83c092"; # cyan
    base0D = "#7fbbb3"; # blue
    base0E = "#d699b6"; # magenta
    base0F = "#704e3f"; # brown
  };
  neovim = {
    plugin = "https://github.com/neanias/everforest-nvim";
    colorscheme = "everforest";
    lualine = "auto";
    setup = "vim.g.everforest_background = 'soft'";
  };
  vscode = "Everforest Dark";
  accent = "base0D";
}
