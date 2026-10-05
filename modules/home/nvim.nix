{
  config,
  pkgs,
  ...
}:

let
  # Same theme.name selected in themes/.
  nvimTheme = config.theme.current.neovim;

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
  # Theme presets supply the colorscheme instead of Stylix.
  stylix.targets.neovim.enable = false;

  home = {
    # nvim-treesitter compiles parsers locally.
    packages = [
      pkgs.gcc
      pkgs.tree-sitter
    ];
    sessionVariables.NVIM_THEME_LUA = themeLua;

    file = {
      ".config/nvim".source = config.lib.file.mkOutOfStoreSymlink "${config.repoPath}/config/nvim";
      ".config/lazygit/config.yml".source =
        config.lib.file.mkOutOfStoreSymlink "${config.repoPath}/config/nvim/lazygit/config.yml";
    };
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    sideloadInitLua = true;
  };
}
