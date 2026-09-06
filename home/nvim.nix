{
  config,
  pkgs,
  ...
}:

let
  # same theme.name selected in home/theme.nix
  nvimTheme = (import ./theme.nix).themes.${config.theme.name}.neovim;

  themeLua = pkgs.writeText "nvim-theme.lua" ''
    return {
      plugin = "${nvimTheme.plugin}",
      colorscheme = "${nvimTheme.colorscheme}",
      lualine = "${nvimTheme.lualine}",
      setup = function() ${nvimTheme.setup or ""} end,
    }
  '';
in
{
  # gcc + tree-sitter CLI: needed by nvim-treesitter to compile parsers
  home.packages = [ pkgs.gcc pkgs.tree-sitter ];

  # colorscheme picked dynamically from theme.name, don't let stylix override it
  stylix.targets.neovim.enable = false;

  # init.lua dofile()s this for its plugin/colorscheme/lualine choice, falling
  # back to a baked-in default if unset (keeps init.lua usable standalone,
  # see its own top comment)
  home.sessionVariables.NVIM_THEME_LUA = "${themeLua}";

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
