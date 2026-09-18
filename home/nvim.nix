{
  config,
  pkgs,
  lib,
  ...
}:

let
  # Stable path keeps existing shells from launching nvim with an old theme.
  themeFile = "${config.xdg.cacheHome}/nvim-theme.lua";
  # same theme.name selected in themes/.
  nvimTheme = (import ../themes).themes.${config.theme.name}.neovim;

  themeLua = pkgs.writeText "nvim-theme.lua" ''
    return {
      plugin = "${nvimTheme.plugin}",
      colorscheme = "${nvimTheme.colorscheme}",
      lualine = "${nvimTheme.lualine}",
      setup = function() ${nvimTheme.setup or ""} end,
    }
  '';

  # Sourced in already-running instances (see the activation hook below).
  themeReload = pkgs.writeText "nvim-theme-reload.lua" ''
    local ok, t = pcall(dofile, "${themeFile}")
    if not ok or type(t) ~= "table" then return end

    -- Install the selected theme plugin when needed.
    pcall(vim.pack.add, { t.plugin })
    pcall(t.setup)
    pcall(vim.cmd.colorscheme, t.colorscheme)

    -- Preserve live lualine sections while changing its theme.
    local okl, lualine = pcall(require, "lualine")
    if okl then
      pcall(function()
        lualine.setup(vim.tbl_deep_extend("force", lualine.get_config(), { options = { theme = t.lualine } }))
      end)
    end
  '';
in
{
  # Theme presets supply the colorscheme instead of Stylix.
  stylix.targets.neovim.enable = false;

  home = {
    # nvim-treesitter compiles parsers locally.
    packages = [ pkgs.gcc pkgs.tree-sitter ];
    sessionVariables.NVIM_THEME_LUA = themeFile;

    # Reload live instances without disturbing insert mode.
    activation.nvimTheme = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run install -Dm644 ${themeLua} "${themeFile}.new"
    run mv -f "${themeFile}.new" "${themeFile}"

    for sock in "''${XDG_RUNTIME_DIR:-/run/user/$UID}"/nvim.*; do
      [ -S "$sock" ] || continue
      run ${pkgs.coreutils}/bin/timeout 2 ${config.programs.neovim.finalPackage}/bin/nvim \
        --server "$sock" --remote-expr "luaeval('dofile(\"${themeReload}\")')" \
        >/dev/null 2>&1 || true
    done
  '';

    file = {
      ".config/nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.src/nixos/config/nvim";
      ".config/lazygit/config.yml".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.src/nixos/config/nvim/lazygit/config.yml";
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
