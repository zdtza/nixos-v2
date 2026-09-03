{ ... }:

{
  programs.npm.enable = true;
  # making sure that npm lib folder exists for npm link commands
  home.file.".npm/lib/.keep".text = "";
}
