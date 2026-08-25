{ repoFile, ... }:

{
  home.file.".config/nvim".source = repoFile "config/nvim";
  home.file.".config/lazygit/config.yml".source = repoFile "config/nvim/lazygit/config.yml";

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

  # The neovim-wrapped .desktop file ships with Terminal=true, expecting
  # the desktop environment to know how to spawn a terminal emulator for
  # it. GIO (used by Nautilus/GTK launchers) only probes a hardcoded list
  # of terminals (gnome-terminal, xterm, ...) and has no idea kitty is
  # our terminal, so "Open With Neovim wrapper" fails with "Unable to
  # find terminal required for application". Override it to spawn kitty
  # directly instead of asking the launcher to find a terminal.
  xdg.desktopEntries.nvim = {
    name = "Neovim";
    genericName = "Terminal based text editor";
    comment = "Edit text files";
    exec = "kitty nvim %F";
    terminal = false;
    icon = "nvim";
    mimeType = [
      "text/english"
      "text/plain"
      "text/x-makefile"
      "text/x-c++hdr"
      "text/x-c++src"
      "text/x-chdr"
      "text/x-csrc"
      "text/x-java"
      "text/x-moc"
      "text/x-pascal"
      "text/x-tcl"
      "text/x-tex"
      "application/x-shellscript"
      "text/x-c"
      "text/x-c++"
    ];
  };
}
