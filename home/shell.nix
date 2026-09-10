{ ... }:

{
  # disabling stylix's fish target, its OSC sequences also recolor the tty console
  stylix.targets.fish.enable = false;

  programs.fish = {
    enable = true;

    # loading secrets from a stable per-user path, independent of flake checkout/cwd
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

    # nixos aliases for faster rebuilds, updates and home manager switching
    functions.rb = ''
      command git -C "$HOME/.src/nixos" add --all; or return $status
      command pkexec --disable-internal-agent /run/current-system/sw/bin/nixos-rebuild switch --flake "$HOME/.src/nixos#"(hostname) --option warn-dirty false $argv; or return $status
    '';

    functions.sw = ''
      command git -C "$HOME/.src/nixos" add --all; or return $status
      set -l activation (command nix build "$HOME/.src/nixos#nixosConfigurations."(hostname)".config.home-manager.users.$USER.home.activationPackage" --no-link --print-out-paths --option warn-dirty false); or return $status
      "$activation/activate"; or return $status
    '';

    # Manual, never part of `sw`/`rb`: builds each theme's home generation
    # into ~/.cache/theme-generations/<theme>, which is what `select-theme`
    # activates out of. Run it when a theme's colors/wallpapers change, or
    # after config edits the other themes should carry; until then switching
    # keeps serving the last build -- instantly, and never touching nix.
    functions.build-themes = ''
      command select-theme --build $argv
    '';

    functions.up = ''
      command git -C "$HOME/.src/nixos" add --all; or return $status
      command nix flake update --flake "$HOME/.src/nixos" --option warn-dirty false; or return $status
      rb
    '';

    # aliases for the shell
    shellAliases = {
      ls = "eza -l --group-directories-first --icons=auto";
      lsa = "ls -a";
      lt = "eza --tree --level=4 --long --icons --git";
      lta = "lt -a";

      startw = "uwsm start hyprland-uwsm.desktop";
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

  # shell prompt
  programs.starship = {
    enable = true;
    settings = {
      add_newline = true;
      format = "$directory$character";

      directory = {
        format = "[$path](green) ";
        truncation_length = 0;
        truncate_to_repo = false;
        truncation_symbol = "";
      };

      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
      };
    };
  };
}
