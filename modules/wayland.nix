# hyprland/wayland desktop stack, no gpu-vendor or form-factor config here
{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.wayland-desktop;
  # Pre-login fallback; home-manager's theme.name overrides the user palette.
  fallbackTheme = (import ../themes).themes.tokyo-night;
in
{
  options.wayland-desktop.autoLoginUser = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "User to auto-login as on cold boot, straight into hyprland (bypassing the greeter). Session still starts locked.";
  };

  config = {
  programs = {
    # D-Bus settings let running GTK apps pick up appearance changes.
    dconf.enable = true;
    hyprland = {
    enable = true;
    xwayland.enable = true;
    withUWSM = true;
    };
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  security = {
    rtkit.enable = true;
    polkit = {
      enable = true;
      enablePkexecWrapper = true;
    };
    pam.services.greetd.enableGnomeKeyring = true;
  };

  services = {
    pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

    udisks2.enable = true;
    gvfs.enable = true;

  # cups ships its own config UI on localhost:631, no gui package needed.
  # avahi is what makes network printers show up in the print dialog at all.
    printing.enable = true;
    avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # secret service backend for gvfs/nautilus mount credentials
    gnome.gnome-keyring.enable = true;

  # tui login manager, launches hyprland through uwsm on login
  # wrapped in a script, greetd's toml parser chokes on a long inline command
    greetd = {
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
  };

  xdg.portal = {
    enable = true;
    # hyprland's module adds gtk automatically, forcing exact backends for the terminal file picker
    extraPortals = lib.mkForce (
      with pkgs;
      [
        xdg-desktop-portal-hyprland
        xdg-desktop-portal-termfilechooser
        # GTK4 needs the Settings portal for live appearance changes on Wayland.
        xdg-desktop-portal-gtk
      ]
    );
    config.hyprland = {
      default = [ "hyprland" ];
      "org.freedesktop.impl.portal.FileChooser" = [ "termfilechooser" ];
      # gtk backend stays pinned to this one interface, so it cannot quietly
      # take over the file picker the line above exists to control.
      "org.freedesktop.impl.portal.Settings" = [ "gtk" ];
    };
  };

  stylix = {
    enable = true;
    polarity = "dark";
    base16Scheme = fallbackTheme.colors;
    image = fallbackTheme.wallpaper;

    # keeping boot and virtual consoles on their default palette
    targets = {
      console.enable = false;
      fish.enable = false;
    };

    cursor = {
      package = pkgs.adwaita-icon-theme;
      name = "Adwaita";
      size = 24;
    };

    fonts = {
      sizes = {
        applications = 11;
        terminal = 11.5;
        desktop = 11;
        popups = 11;
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
