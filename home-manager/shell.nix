{ config, ... }:

{
  stylix.targets.fish.colors.override = {
    base03 = config.lib.stylix.colors.base05; # muted -> foreground
    base0B = config.lib.stylix.colors.base0E; # green -> magenta
  };

  programs.fish = {
    enable = true;

    # Load secrets from stable per-user path, independent of flake checkout/cwd.
    interactiveShellInit = ''
      set -g fish_greeting
      set -l env_file "$XDG_CONFIG_HOME/environment/secrets.env"

      if test -f "$env_file"
        for line in (grep -Ev '^\s*(#|$)' "$env_file")
          set -l parts (string split -m1 "=" $line)
          set -gx $parts[1] $parts[2]
        end
      end
    '';

    # aliases for the shell
    shellAliases = {
      ls = "eza -l --group-directories-first --icons=auto";
      lsa = "ls -a";
      lt = "eza --tree --level=4 --long --icons --git";
      lta = "lt -a";

      startw = "uwsm start hyprland-uwsm.desktop";
      rb = "sudo nixos-rebuild switch --flake ~/.src/nixos";
      ff = "fastfetch";
    };
  };

  # better cd
  programs.zoxide = {
    enable = true;
    options = [
      "--cmd"
      "cd"
    ];
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
