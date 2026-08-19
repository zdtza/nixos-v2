{ config, ... }:
{
  programs.git = {
    enable = true;
    settings = {
      user.name = "Connor du Toit";
      user.email = "connordutoit@gmail.com";
      init.defaultBranch = "main";
    };
  };
}