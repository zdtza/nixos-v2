{ repoFile, ... }:

{
  home.file.".pi/agent/APPEND_SYSTEM.md".source = repoFile "dotfiles/pi/agent/APPEND_SYSTEM.md";
}
