{ config, pkgs, ... }:

{
  # gcc + tree-sitter CLI: needed by nvim-treesitter to compile parsers
  home.packages = [ pkgs.gcc pkgs.tree-sitter ];

  # tokyonight colorscheme picked explicitly, don't let stylix override it
  stylix.targets.neovim.enable = false;

  home.file.".config/nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.src/nixos/config/nvim";
  home.file.".config/lazygit/config.yml".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.src/nixos/config/nvim/lazygit/config.yml";

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    sideloadInitLua = true;
  };
}
