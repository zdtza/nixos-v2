{ config, ... }:
{
  programs.git = {
    enable = true;
    userName = "Connor du Toit";
    userEmail = "connordutoit@gmail.com";
    settings = {
      init.defaultBranch = "main";
    };
  };
}