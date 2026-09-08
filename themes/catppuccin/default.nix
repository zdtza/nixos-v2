{
  wallpaper = ./wallpapers/1-totoro.jpg;
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
  vscode = "Catppuccin Mocha";
  gtkAccent = "purple"; # nearest to base0E's mauve
  iconTheme = "Yaru-purple"; # see themes/tokyo-night for the variant list
}
