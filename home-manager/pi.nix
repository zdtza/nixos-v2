{ self, ... }:

{
  home.file.".pi/agent/APPEND_SYSTEM.md".source = self + "/dotfiles/pi/agent/APPEND_SYSTEM.md";
}
