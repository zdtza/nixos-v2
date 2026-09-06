# Pure data: name -> { colors (stylix base16Scheme), wallpaper }.
# No lib/config args on purpose, so both the themes.nix module and
# scripts/theme-select.sh can `nix eval` this file directly.
#
# Add a theme by dropping wallpapers in ../../assets/wallpapers/<name>/ and a
# new attrset here. `wallpaper` is the default; the rest of that folder is
# just extra options for a future wallpaper-cycle feature. base16 key
# meanings: see https://github.com/chriskempson/base16/blob/main/styling.md
# Wallpapers sourced from https://github.com/basecamp/omarchy (themes/*/backgrounds).
{
  tokyo-night = {
    wallpaper = ../../assets/wallpapers/tokyo-night/0-winding-road.jpg;
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
      base0C = "#3dcce5"; # cyan
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
  };

  catppuccin-mocha = {
    wallpaper = ../../assets/wallpapers/catppuccin-mocha/2-waves.jpg;
    colors = {
      base00 = "#1e1e2e";
      base01 = "#181825";
      base02 = "#313244";
      base03 = "#45475a";
      base04 = "#585b70";
      base05 = "#cdd6f4";
      base06 = "#f5e0dc";
      base07 = "#b4befe";
      base08 = "#f38ba8";
      base09 = "#fab387";
      base0A = "#f9e2af";
      base0B = "#a6e3a1";
      base0C = "#94e2d5";
      base0D = "#89b4fa";
      base0E = "#cba6f7";
      base0F = "#f2cdcd";
    };
    neovim = {
      plugin = "https://github.com/catppuccin/nvim";
      # catppuccin.nvim's own colorscheme is flavour-less; flavour is set in setup()
      setup = "require('catppuccin').setup({ flavour = 'mocha' })";
      colorscheme = "catppuccin";
      # lualine ships no catppuccin theme file; "auto" reads the active colorscheme
      lualine = "auto";
    };
  };

  gruvbox-dark = {
    wallpaper = ../../assets/wallpapers/gruvbox-dark/1-the-backwater.jpg;
    colors = {
      base00 = "#282828";
      base01 = "#3c3836";
      base02 = "#504945";
      base03 = "#665c54";
      base04 = "#bdae93";
      base05 = "#d5c4a1";
      base06 = "#ebdbb2";
      base07 = "#fbf1c7";
      base08 = "#fb4934";
      base09 = "#fe8019";
      base0A = "#fabd2f";
      base0B = "#b8bb26";
      base0C = "#8ec07c";
      base0D = "#83a598";
      base0E = "#d3869b";
      base0F = "#d65d0e";
    };
    neovim = {
      plugin = "https://github.com/ellisonleao/gruvbox.nvim";
      colorscheme = "gruvbox";
      lualine = "gruvbox";
    };
  };
}
