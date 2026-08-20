{ ... }:

{
  # need to actually enable it so stylix picks it up and themes it
  programs.npm.enable = true;
  # making sure that npm lib folder exists for npm link commands
  home.file.".npm/lib/.keep".text = "";
}
