{ ... }:
{
  # setting up default git credentials for private github
  programs.git = {
    enable = true;
    settings = {
      user.name = "Connor du Toit";
      user.email = "connordutoit@gmail.com";
      init.defaultBranch = "main";
    };
  };
}
