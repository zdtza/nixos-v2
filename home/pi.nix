{ config, ... }:

{
  # symlinking prompt extension
  home.file.".pi/agent/APPEND_SYSTEM.md".source
    = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/symlink/pi/agent/APPEND_SYSTEM.md";
}
