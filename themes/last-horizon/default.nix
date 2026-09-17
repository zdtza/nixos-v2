# Generated from ~/omarchy/themes/last-horizon (colors.toml, neovim.lua, vscode.json).
# Same shape as themes/tokyo-night -- see that file for what each field drives.
{
  wallpaper = ./wallpapers/1-eyes-wide.jpg;
  polarity = "dark";
  colors = {
    base00 = "#0c0b0c"; # background
    base01 = "#090809"; # dark_background
    base02 = "#584e51"; # selection
    base03 = "#584e51"; # muted
    base04 = "#584e51"; # dark_foreground
    base05 = "#FAFCFB"; # foreground
    base06 = "#cfd3cd"; # light_foreground
    base07 = "#e2dddc"; # bright_foreground
    base08 = "#c38b7b"; # red
    base09 = "#c38b7b"; # orange
    base0A = "#6B5E73"; # yellow
    base0B = "#87a9b0"; # green
    base0C = "#a5a0b6"; # cyan
    base0D = "#b59790"; # blue
    base0E = "#c4d8e2"; # magenta
    base0F = "#584e51"; # brown
  };
  neovim = {
    plugin = "https://github.com/RRethy/base16-nvim";
    colorscheme = "";
    lualine = "auto";
    setup = "require('base16-colorscheme').setup({ base00 = '#0c0b0c', base01 = '#090809', base02 = '#584e51', base03 = '#584e51', base04 = '#584e51', base05 = '#FAFCFB', base06 = '#cfd3cd', base07 = '#e2dddc', base08 = '#c38b7b', base09 = '#c38b7b', base0A = '#6B5E73', base0B = '#87a9b0', base0C = '#a5a0b6', base0D = '#b59790', base0E = '#c4d8e2', base0F = '#584e51' })";
  };
  vscode = "Ship at Sea";
  accent = "base0D";
}
