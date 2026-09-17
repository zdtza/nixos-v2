# Generated from ~/omarchy/themes/ethereal (colors.toml, neovim.lua, vscode.json).
# Same shape as themes/tokyo-night -- see that file for what each field drives.
{
  wallpaper = ./wallpapers/1-cosmic.jpg;
  polarity = "dark";
  colors = {
    base00 = "#060B1E"; # background
    base01 = "#040816"; # dark_background
    base02 = "#252e56"; # selection
    base03 = "#6d7db6"; # muted
    base04 = "#6d7db6"; # dark_foreground
    base05 = "#ffcead"; # foreground
    base06 = "#c9b8a6"; # light_foreground
    base07 = "#ffcead"; # bright_foreground
    base08 = "#ED5B5A"; # red
    base09 = "#eb8b54"; # orange
    base0A = "#E9BB4F"; # yellow
    base0B = "#92a593"; # green
    base0C = "#a3bfd1"; # cyan
    base0D = "#7d82d9"; # blue
    base0E = "#c89dc1"; # magenta
    base0F = "#75452a"; # brown
  };
  neovim = {
    plugin = "https://github.com/RRethy/base16-nvim";
    colorscheme = "";
    lualine = "auto";
    setup = "require('base16-colorscheme').setup({ base00 = '#060B1E', base01 = '#040816', base02 = '#252e56', base03 = '#6d7db6', base04 = '#6d7db6', base05 = '#ffcead', base06 = '#c9b8a6', base07 = '#ffcead', base08 = '#ED5B5A', base09 = '#eb8b54', base0A = '#E9BB4F', base0B = '#92a593', base0C = '#a3bfd1', base0D = '#7d82d9', base0E = '#c89dc1', base0F = '#75452a' })";
  };
  vscode = "Default Dark Modern";
  accent = "base0D";
}
