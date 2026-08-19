{ ... }:

{
  flake.homeModules.shell =
    { ... }:
    {
      programs.zoxide = {
        enable = true;
        options = [ "--cmd" "cd" ];
      };

      programs.bash = {
        enable = true;

        shellAliases = {
          ls = "eza -l --group-directories-first --icons=auto";
          lsa = "ls -a";
          lt = "eza --tree --level=2 --long --icons --git";
          lta = "lt -a";
        };
      };
    };
}
