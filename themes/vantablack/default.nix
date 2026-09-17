# Generated from ~/omarchy/themes/vantablack (colors.toml, neovim.lua, vscode.json).
# Same shape as themes/tokyo-night -- see that file for what each field drives.
{
  wallpaper = ./wallpapers/0-dot-hands.jpg;
  polarity = "dark";
  colors = {
    base00 = "#000000"; # background
    base01 = "#090909"; # dark_background
    base02 = "#1a1a1a"; # selection
    base03 = "#7a7a7a"; # muted
    base04 = "#505050"; # dark_foreground
    base05 = "#ffffff"; # foreground
    base06 = "#ececec"; # light_foreground
    base07 = "#ffffff"; # bright_foreground
    base08 = "#a4a4a4"; # red
    base09 = "#b9b9b9"; # orange
    base0A = "#cecece"; # yellow
    base0B = "#b6b6b6"; # green
    base0C = "#b0b0b0"; # cyan
    base0D = "#8d8d8d"; # blue
    base0E = "#9b9b9b"; # magenta
    base0F = "#5c5c5c"; # brown
  };
  neovim = {
    plugin = "https://github.com/RRethy/base16-nvim";
    colorscheme = "";
    lualine = "auto";
    setup = "require('base16-colorscheme').setup({ base00 = '#000000', base01 = '#090909', base02 = '#1a1a1a', base03 = '#7a7a7a', base04 = '#505050', base05 = '#ffffff', base06 = '#ececec', base07 = '#ffffff', base08 = '#a4a4a4', base09 = '#b9b9b9', base0A = '#cecece', base0B = '#b6b6b6', base0C = '#b0b0b0', base0D = '#8d8d8d', base0E = '#9b9b9b', base0F = '#5c5c5c' })";
  };
  vscode = "Default Dark Modern";
  accent = "base0D";
}
