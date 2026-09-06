# hyprland/wayland desktop stack, no gpu-vendor or form-factor config here
{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.wayland-desktop;
  # NixOS-level stylix requires *some* scheme/image; home-manager's
  # theme.name (home/theme.nix) overrides both for the real, switchable
  # selection, this is only the fixed pre-login/system-level fallback
  fallbackTheme = (import ../home/theme.nix).themes.tokyo-night;
in
{
  options.wayland-desktop.autoLoginUser = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "User to auto-login as on cold boot, straight into hyprland (bypassing the greeter). Session still starts locked.";
  };

  config = {
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    withUWSM = true;
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  security.rtkit.enable = true;
  security.polkit = {
    enable = true;
    enablePkexecWrapper = true;
  };

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  services.udisks2.enable = true;
  services.gvfs.enable = true;

  # secret service backend for gvfs/nautilus mount credentials
  services.gnome.gnome-keyring.enable = true;

  # dconf/gsettings: GTK3+/libadwaita apps watch these live over D-Bus, so
  # mirroring theme.name here (home/appearance.nix) re-themes already-open
  # GTK apps on `sw`, not just ones launched afterward
  programs.dconf.enable = true;

  # tui login manager, launches hyprland through uwsm on login
  # wrapped in a script, greetd's toml parser chokes on a long inline command
  services.greetd = {
    enable = true;
    settings = {
      default_session.command = lib.getExe (
        pkgs.writeShellScriptBin "tuigreet-session" ''
          exec ${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-user-session --cmd "uwsm start hyprland-uwsm.desktop"
        ''
      );
    } // lib.optionalAttrs (cfg.autoLoginUser != null) {
      # cold-boot straight into hyprland, no greeter; quickshell locks the
      # session on startup (see home/quickshell.nix) so nothing's exposed.
      # falls back to default_session (the greeter) if this session ever exits.
      initial_session = {
        command = "uwsm start hyprland-uwsm.desktop";
        user = cfg.autoLoginUser;
      };
    };
  };
  security.pam.services.greetd.enableGnomeKeyring = true;

  xdg.portal = {
    enable = true;
    # hyprland's module adds gtk automatically, forcing exact backends for the terminal file picker
    extraPortals = lib.mkForce (
      with pkgs;
      [
        xdg-desktop-portal-hyprland
        xdg-desktop-portal-termfilechooser
      ]
    );
    config.hyprland = {
      default = [ "hyprland" ];
      "org.freedesktop.impl.portal.FileChooser" = [ "termfilechooser" ];
    };
  };

  stylix = {
    enable = true;
    polarity = "dark";
    base16Scheme = fallbackTheme.colors;
    image = fallbackTheme.wallpaper;

    # keeping boot and virtual consoles on their default palette
    targets.console.enable = false;
    targets.fish.enable = false;

    cursor = {
      package = pkgs.adwaita-icon-theme;
      name = "Adwaita";
      size = 24;
    };

    # base16Scheme and image come from home-manager's theme.name (home/theme.nix),
    # which overrides these NixOS-level defaults -- see stylix's mkDefault forwarding

    fonts = {
      sizes = {
        applications = 10;
        terminal = 11.5;
        desktop = 10;
        popups = 10;
      };

      serif = {
        package = pkgs.source-serif-pro;
        name = "Source Serif Pro";
      };

      sansSerif = {
        package = pkgs.inter;
        name = "Inter";
      };

      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font";
      };

      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
    };
  };
  };
}
