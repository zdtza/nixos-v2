# Generated from ~/omarchy/themes/white (colors.toml, neovim.lua, vscode.json).
# Same shape as themes/tokyo-night -- see that file for what each field drives.
{
  wallpaper = ./wallpapers/1-white.jpg;
  polarity = "light";
  colors = {
    base00 = "#ffffff"; # background
    base01 = "#f5f5f5"; # dark_background
    base02 = "#c0c0c0"; # selection
    base03 = "#808080"; # muted
    base04 = "#c0c0c0"; # dark_foreground
    base05 = "#000000"; # foreground
    base06 = "#000000"; # light_foreground
    base07 = "#000000"; # bright_foreground
    base08 = "#2a2a2a"; # red
    base09 = "#2a2a2a"; # orange
    base0A = "#4a4a4a"; # yellow
    base0B = "#3a3a3a"; # green
    base0C = "#3e3e3e"; # cyan
    base0D = "#1a1a1a"; # blue
    base0E = "#2e2e2e"; # magenta
    base0F = "#808080"; # brown
  };
  neovim = {
    plugin = "https://github.com/RRethy/base16-nvim";
    colorscheme = "";
    lualine = "auto";
    setup = "require('base16-colorscheme').setup({ base00 = '#ffffff', base01 = '#f5f5f5', base02 = '#c0c0c0', base03 = '#808080', base04 = '#c0c0c0', base05 = '#000000', base06 = '#000000', base07 = '#000000', base08 = '#2a2a2a', base09 = '#2a2a2a', base0A = '#4a4a4a', base0B = '#3a3a3a', base0C = '#3e3e3e', base0D = '#1a1a1a', base0E = '#2e2e2e', base0F = '#808080' })";
  };
  vscode = "Default Light Modern";
  accent = "base0F";
}
