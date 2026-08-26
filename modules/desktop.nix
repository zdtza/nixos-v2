# Hyprland/Wayland desktop stack. Nothing GPU-vendor or form-factor specific
# lives here (see hardware.nvidia / services.tlp in the host file for that).
# Import directly into a host's `imports` to use.
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

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  services.udisks2.enable = true;
  services.gvfs.enable = true;

  xdg.portal = {
    enable = true;
    # Hyprland's NixOS module adds GTK automatically; force exact backends for terminal file picker.
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

    # Keep boot and virtual consoles on their default palette.
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
      base0C = "#449dab"; # cyan
      base0D = "#7aa2f7"; # blue
      base0E = "#ad8ee6"; # magenta
      base0F = "#75493d"; # brown
    };

    fonts = {
      sizes = {
        applications = 10;
        terminal = 12;
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
