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

    functions.rb = ''
      set -l state_home "$XDG_STATE_HOME"
      if test -z "$state_home"
        set state_home "$HOME/.local/state"
      end

      set -l repo "$HOME/.src/nixos"
      set -l log_dir "$state_home/nixos-rebuild"
      set -l log_file "$log_dir/latest.log"
      command mkdir -p "$log_dir"

      # Authenticate before redirecting output so sudo's prompt stays visible.
      command sudo -v; or return $status

      printf 'Rebuilding NixOS...\n'
      command sudo nixos-rebuild switch --flake "$repo" $argv \
        >"$log_file" 2>&1
      set -l rebuild_status $status

      if test $rebuild_status -eq 0
        set -l profile (command readlink /nix/var/nix/profiles/system)
        set -l generation (string replace -r \
          '^system-([0-9]+)-link$' '$1' (path basename "$profile"))
        # `$version` is Fish's read-only version variable; use distinct name.
        set -l nixos_version (string trim \
          (command cat /run/current-system/nixos-version))
        set -l commit_message "NixOS generation $generation ($nixos_version)"

        printf 'Rebuild complete: %s\n' "$commit_message"
        if not command git -C "$repo" diff --quiet HEAD --
          command git -C "$repo" commit -am "$commit_message"
          return $status
        end
        return 0
      end

      # Nix puts actionable error after evaluation trace as final `error:`
      # block. Extract that complete block, omitting duplicate nested tag and
      # nixos-rebuild's trailing command-failed summary.
      set -l error_file "$log_dir/error.log"
      command sed -E 's/\x1B\[[0-9;]*[mK]//g' "$log_file" | command awk '
        { lines[NR] = $0 }
        /^[[:space:]]*error:/ { start = NR }
        END {
          if (!start)
            exit 1

          finish = NR
          for (i = start + 1; i <= NR; i++) {
            if (lines[i] ~ /^Command .*returned non-zero exit status/ ) {
              finish = i - 1
              break
            }
          }
          while (finish > start && lines[finish] ~ /^[[:space:]]*$/)
            finish--

          sub(/^[[:space:]]*error:[[:space:]]*/, "", lines[start])
          print lines[start]
          for (i = start + 1; i <= finish; i++)
            print lines[i]
        }
      ' >"$error_file"

      printf '\n'
      if test -s "$error_file"
        set_color --bold red
        printf 'error:'
        set_color normal
        printf '\n'
        command cat "$error_file"
      else
        printf 'Rebuild failed; no error block found.\n'
      end
      return $rebuild_status
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
