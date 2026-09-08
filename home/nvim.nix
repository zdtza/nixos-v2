{
  config,
  pkgs,
  lib,
  ...
}:

let
  # Stable path, not the per-generation store path: a shell opened before a
  # theme switch still exports the old one, and so would start nvim on the
  # previous colorscheme. This file is rewritten in place on every activation.
  themeFile = "${config.xdg.cacheHome}/nvim-theme.lua";
  # same theme.name selected in themes/
  nvimTheme = (import ../themes).themes.${config.theme.name}.neovim;

  themeLua = pkgs.writeText "nvim-theme.lua" ''
    return {
      plugin = "${nvimTheme.plugin}",
      colorscheme = "${nvimTheme.colorscheme}",
      lualine = "${nvimTheme.lualine}",
      setup = function() ${nvimTheme.setup or ""} end,
    }
  '';

  # Sourced in already-running instances (see the activation hook below). Each
  # step is pcall'd: a half-applied theme beats an error popping up over
  # whatever the user is typing into.
  themeReload = pkgs.writeText "nvim-theme-reload.lua" ''
    local ok, t = pcall(dofile, "${themeFile}")
    if not ok or type(t) ~= "table" then return end

    -- No-op when the plugin is already there; clones it when the new theme
    -- brings one this instance has never loaded.
    pcall(vim.pack.add, { t.plugin })
    pcall(t.setup)
    pcall(vim.cmd.colorscheme, t.colorscheme)

    -- Merge over the *live* config rather than calling setup() with a bare
    -- options table, which would rebuild lualine from its defaults and drop
    -- the sections init.lua configured.
    local okl, lualine = pcall(require, "lualine")
    if okl then
      pcall(function()
        lualine.setup(vim.tbl_deep_extend("force", lualine.get_config(), { options = { theme = t.lualine } }))
      end)
    end
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
  home.sessionVariables.NVIM_THEME_LUA = themeFile;

  # nvim reads its colorscheme once at startup, so a theme switch has to be
  # pushed into the instances that are already open. Since 0.10 every nvim
  # listens on $XDG_RUNTIME_DIR/nvim.<pid>.<n> without being asked, and
  # --remote-expr evaluates in the remote without touching its input queue --
  # unlike --remote-send, which would need <C-\><C-N> and would yank the user
  # out of insert mode mid-word. timeout: an instance sitting in a modal prompt
  # answers late or not at all, and a theme switch must not block on it.
  home.activation.nvimTheme = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run install -Dm644 ${themeLua} "${themeFile}.new"
    run mv -f "${themeFile}.new" "${themeFile}"

    for sock in "''${XDG_RUNTIME_DIR:-/run/user/$UID}"/nvim.*; do
      [ -S "$sock" ] || continue
      run ${pkgs.coreutils}/bin/timeout 2 ${config.programs.neovim.finalPackage}/bin/nvim \
        --server "$sock" --remote-expr "luaeval('dofile(\"${themeReload}\")')" \
        >/dev/null 2>&1 || true
    done
  '';

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
