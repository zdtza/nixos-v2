{ config, ... }:

{
  home.file.".config/nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/Nixodus/symlink/nvim";
  home.file.".config/lazygit/config.yml".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/Nixodus/symlink/nvim/lazygit/config.yml";

  # LazyVim ships its own Tokyo Night colorscheme - skip Stylix repainting it.
  stylix.targets.neovim.enable = false;

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    # home-manager always writes a small init.lua (disables unused
    # providers); sideload it via a wrapper flag instead of the default
    # xdg.configFile write, so it doesn't collide with our own init.lua.
    sideloadInitLua = true;
  };
}
