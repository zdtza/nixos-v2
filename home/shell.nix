{ ... }:

{
  programs.bash = {
    enable = true;

    initExtra = ''
      if [ -f "$HOME/.config/Nixodus/.env" ]; then
        set -a
        source "$HOME/.config/Nixodus/.env"
        set +a
      fi
    '';

    # aliases for the shell
    shellAliases = {
      ls = "eza -l --group-directories-first --icons=auto";
      lsa = "ls -a";
      lt = "eza --tree --level=2 --long --icons --git";
      lta = "lt -a";

      startw = "uwsm start hyprland-uwsm.desktop";
      rb = "sudo nixos-rebuild switch --flake ~/.config/Nixodus";
    };
  };

  # better cd
  programs.zoxide = {
    enable = true;
    options = [ "--cmd" "cd" ];
  };

  # custom pointer
  programs.starship = {
    enable = true;
    settings = {
      add_newline = true;
      format = "$directory$character";

      directory = {
        format = "[$path](green) ";
        truncation_length = 3;
        truncation_symbol = "";
      };

      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
      };
    };
  };
}
