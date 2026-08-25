{ repoFile, ... }:

{
  home.file.".pi/agent/APPEND_SYSTEM.md".source = repoFile "config/pi/agent/APPEND_SYSTEM.md";
}
