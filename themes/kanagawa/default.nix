# Generated from ~/omarchy/themes/kanagawa (colors.toml, neovim.lua, vscode.json).
# Same shape as themes/tokyo-night -- see that file for what each field drives.
{
  wallpaper = ./wallpapers/1-kanagawa.jpg;
  polarity = "dark";
  colors = {
    base00 = "#1f1f28"; # background
    base01 = "#17171e"; # dark_background
    base02 = "#363646"; # selection
    base03 = "#54546D"; # muted
    base04 = "#727169"; # dark_foreground
    base05 = "#dcd7ba"; # foreground
    base06 = "#c8c093"; # light_foreground
    base07 = "#dcd7ba"; # bright_foreground
    base08 = "#c34043"; # red
    base09 = "#c17158"; # orange
    base0A = "#c0a36e"; # yellow
    base0B = "#76946a"; # green
    base0C = "#6a9589"; # cyan
    base0D = "#7e9cd8"; # blue
    base0E = "#957fb8"; # magenta
    base0F = "#60382c"; # brown
  };
  neovim = {
    plugin = "https://github.com/rebelot/kanagawa.nvim";
    colorscheme = "kanagawa";
    lualine = "auto";
  };
  vscode = "Kanagawa";
  accent = "base05";
}
