{ config, ... }:

{
  home.file.".config/nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.src/nixos/config/nvim";
  home.file.".config/lazygit/config.yml".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.src/nixos/config/nvim/lazygit/config.yml";

  # LazyVim ships its own Tokyo Night colorscheme - skip Stylix repainting it.
  stylix.targets.neovim.enable = false;

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    sideloadInitLua = true;
  };

  xdg.desktopEntries.nvim = {
    name = "Neovim";
    genericName = "Terminal based text editor";
    comment = "Edit text files";
    exec = "kitty nvim %F";
    terminal = false;
    icon = "nvim";
  };
}
