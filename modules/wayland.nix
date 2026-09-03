# hyprland/wayland desktop stack, no gpu-vendor or form-factor config here
{
  pkgs,
  lib,
  ...
}:
{
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

  # tui login manager, launches hyprland through uwsm on login
  # wrapped in a script, greetd's toml parser chokes on a long inline command
  services.greetd = {
    enable = true;
    settings.default_session.command = lib.getExe (
      pkgs.writeShellScriptBin "tuigreet-session" ''
        exec ${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-user-session --cmd "uwsm start hyprland-uwsm.desktop"
      ''
    );
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
    image = ../assets/wallpapers/winding-road.jpg;

    # keeping boot and virtual consoles on their default palette
    targets.console.enable = false;
    targets.fish.enable = false;

    cursor = {
      package = pkgs.adwaita-icon-theme;
      name = "Adwaita";
      size = 24;
    };

    # default tokyo night theme
    base16Scheme = {
      base00 = "#1a1b26"; # background
      base01 = "#13141c"; # dark_background
      base02 = "#292e42"; # selection
      base03 = "#414868"; # muted
      base04 = "#565f89"; # dark_foreground
      base05 = "#a9b1d6"; # foreground
      base06 = "#b4bee6"; # light_foreground
      base07 = "#c0caf5"; # bright_foreground
      base08 = "#f7768e"; # red
      base09 = "#eb927b"; # orange
      base0A = "#e0af68"; # yellow
      base0B = "#9ece6a"; # green
      base0C = "#0db9d7"; # cyan
      base0D = "#7aa2f7"; # blue
      base0E = "#ad8ee6"; # magenta
      base0F = "#75493d"; # brown
    };

    fonts = {
      sizes = {
        applications = 10;
        terminal = 11.5;
        desktop = 10;
        popups = 10;
      };

      serif = {
        package = pkgs.dejavu_fonts;
        name = "Dejavu Serif";
      };

      sansSerif = {
        package = pkgs.dejavu_fonts;
        name = "Dejavu Sans";
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
}
