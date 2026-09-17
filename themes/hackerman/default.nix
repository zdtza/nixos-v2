# Generated from ~/omarchy/themes/hackerman (colors.toml, neovim.lua, vscode.json).
# Same shape as themes/tokyo-night -- see that file for what each field drives.
{
  wallpaper = ./wallpapers/1-synth-scape.jpg;
  polarity = "dark";
  colors = {
    base00 = "#0B0C16"; # background
    base01 = "#080910"; # dark_background
    base02 = "#1f253a"; # selection
    base03 = "#2d3450"; # muted
    base04 = "#6a6e95"; # dark_foreground
    base05 = "#ddf7ff"; # foreground
    base06 = "#b5c5db"; # light_foreground
    base07 = "#ddf7ff"; # bright_foreground
    base08 = "#50f872"; # red
    base09 = "#50f7a3"; # orange
    base0A = "#50f7d4"; # yellow
    base0B = "#4fe88f"; # green
    base0C = "#7cf8f7"; # cyan
    base0D = "#829dd4"; # blue
    base0E = "#86a7df"; # magenta
    base0F = "#287b51"; # brown
  };
  neovim = {
    plugin = "https://github.com/RRethy/base16-nvim";
    colorscheme = "";
    lualine = "auto";
    setup = "require('base16-colorscheme').setup({ base00 = '#0B0C16', base01 = '#080910', base02 = '#1f253a', base03 = '#2d3450', base04 = '#6a6e95', base05 = '#ddf7ff', base06 = '#b5c5db', base07 = '#ddf7ff', base08 = '#50f872', base09 = '#50f7a3', base0A = '#50f7d4', base0B = '#4fe88f', base0C = '#7cf8f7', base0D = '#829dd4', base0E = '#86a7df', base0F = '#287b51' })";
  };
  vscode = "Hackerman";
  accent = "base09";
}
