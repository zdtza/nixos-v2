{ config, ... }:

{
  # symlinking prompt extension
  home.file.".pi/agent/APPEND_SYSTEM.md".source
    = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/Nixodus/symlink/pi/agent/APPEND_SYSTEM.md";
}
