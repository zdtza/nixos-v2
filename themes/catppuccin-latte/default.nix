# Generated from ~/omarchy/themes/catppuccin-latte (colors.toml, neovim.lua, vscode.json).
# Same shape as themes/tokyo-night -- see that file for what each field drives.
{
  wallpaper = ./wallpapers/1-color-fade.jpg;
  polarity = "light";
  colors = {
    base00 = "#eff1f5"; # background
    base01 = "#e3e4e8"; # dark_background
    base02 = "#ccd0da"; # selection
    base03 = "#acb0be"; # muted
    base04 = "#9ca0b0"; # dark_foreground
    base05 = "#4c4f69"; # foreground
    base06 = "#5c5f77"; # light_foreground
    base07 = "#4c4f69"; # bright_foreground
    base08 = "#d20f39"; # red
    base09 = "#d84e2b"; # orange
    base0A = "#df8e1d"; # yellow
    base0B = "#40a02b"; # green
    base0C = "#179299"; # cyan
    base0D = "#1e66f5"; # blue
    base0E = "#ea76cb"; # magenta
    base0F = "#6c2715"; # brown
  };
  neovim = {
    plugin = "https://github.com/catppuccin/nvim";
    colorscheme = "catppuccin-latte";
    lualine = "auto";
    setup = "require('catppuccin').setup({ flavour = 'latte' })";
  };
  vscode = "Catppuccin Latte";
  accent = "base0D";
}
