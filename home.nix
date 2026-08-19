{ config, pkgs, ... }:

{
  home.stateVersion = "26.05";

  # ls/cd aliases ported from Omarchy's default bash config
  # (/usr/share/omarchy/default/bash/aliases + init), backed by eza/zoxide.
  # --cmd cd makes zoxide replace `cd` natively: a real directory still does
  # a normal cd, anything else is a fuzzy jump - no hand-written wrapper needed.
  programs.zoxide = {
    enable = true;
    options = [ "--cmd" "cd" ];
  };

  programs.bash = {
    enable = true;

    shellAliases = {
      ls = "eza -lh --group-directories-first --icons=auto";
      lsa = "ls -a";
      lt = "eza --tree --level=2 --long --icons --git";
      lta = "lt -a";
    };
  };

  # Out-of-store symlink: ~/.config/hypr points straight at the flake repo
  # (~/Nix/hypr), so editing files there applies immediately - no rebuild,
  # no copy step.
  xdg.configFile."hypr".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Nix/hypr";

  # Reload Hyprland automatically whenever the symlinked config changes.
  systemd.user = {
    paths.hyprland-config-reload = {
      Unit.Description = "Watch mutable Hyprland configuration";
      Path = {
        PathChanged = [
          "${config.home.homeDirectory}/Nix/hypr/hyprland.lua"
          "${config.home.homeDirectory}/Nix/hypr/config"
        ];
        Unit = "hyprland-config-reload.service";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    services.hyprland-config-reload = {
      Unit.Description = "Reload Hyprland configuration";
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.hyprland}/bin/hyprctl reload";
      };
    };
  };
}
