{ pkgs, config, lib, ... }:

let
  # Theme selection lives entirely in home-manager (not NixOS), so switching
  # is `sw` (see home/shell.nix's fish function) -- no sudo, no
  # nixos-rebuild. stylix.base16Scheme/image set here as a plain option
  # beats the NixOS module's own values, which stylix forwards down as
  # mkDefault (see stylix's home-manager-integration.nix), so this cleanly
  # wins. `themes` itself is plain data -- see themes/default.nix.
  themes = (import ../themes).themes;
  gtkAccent = themes.${config.theme.name}.gtkAccent;
  iconTheme = themes.${config.theme.name}.iconTheme;
in
{
  options.theme.name = lib.mkOption {
    type = lib.types.enum (builtins.attrNames themes);
    default = "tokyo-night";
    description = "Selected preset from the themes/ folder (one subfolder per theme).";
  };

  config = {
    stylix = {
      base16Scheme = themes.${config.theme.name}.colors;
      image = themes.${config.theme.name}.wallpaper;
    };

    # `select-theme`/`select-wallpaper` on PATH, no more cd-ing into scripts/ to run them
    home.packages = [
      (pkgs.writeShellScriptBin "select-theme" ''
        exec ${pkgs.bash}/bin/bash ${config.home.homeDirectory}/.src/nixos/scripts/select-theme.sh "$@"
      '')
      (pkgs.writeShellScriptBin "select-wallpaper" ''
        exec ${pkgs.bash}/bin/bash ${config.home.homeDirectory}/.src/nixos/scripts/select-wallpaper.sh "$@"
      '')
    ];

    # GTK itself never re-reads a custom gtk.css -- the provider is loaded once
    # at startup -- so a theme switch used to mean killing every resident GTK
    # app (Nautilus and other single-instance GApplications stay alive in the
    # background after their last window closes, so they never relaunch on
    # their own). home/gtk-live-css now adds a second, file-watching CSS
    # provider inside each GTK process instead, so those apps retint in place
    # and nothing needs killing. If that ever regresses, the fallback is
    # `pkill -9 -x '.nautilus-wrapp'` -- note the comm, not the name: nix wraps
    # the binary and `comm` truncates to 15 chars, so `pkill -x nautilus`
    # silently matches nothing, and `-f` fails too since argv[0] is the
    # wrapper's path.

    # global color scheme for GTK apps, follows stylix polarity
    gtk.colorScheme = if config.stylix.polarity == "light" then "light" else "dark";

    # Per-theme icon colors, same trick as ~/omarchy: one yaru-theme package
    # ships every accent variant (Yaru-purple, Yaru-olive, ...) with the
    # folder/mime art already recolored, so a theme only names the variant
    # (themes/*/iconTheme) instead of shipping SVGs. Omarchy additionally
    # symlinks Adwaita's go-previous/next-symbolic into Yaru for Nautilus's
    # nav arrows; nixpkgs' Yaru already ships both, so that patch is skipped.
    gtk.iconTheme = {
      name = iconTheme;
      package = pkgs.yaru-theme;
    };

    # mirrored into dconf too (programs.dconf.enable in modules/wayland.nix):
    # GTK3+/libadwaita apps subscribe to this over D-Bus and re-theme live,
    # settings.ini above only covers apps launched after the fact
    dconf.settings."org/gnome/desktop/interface" = {
      color-scheme = if config.stylix.polarity == "light" then "prefer-light" else "prefer-dark";
      icon-theme = iconTheme;
      # libadwaita (GTK4) apps -- gnome-calculator, gnome-disks, Nautilus --
      # hold an AdwStyleManager that watches this key and re-renders live.
      accent-color = gtkAccent;
    };

    # stylix's qt target wires up qt6ct/qt5ct but never sets icon_theme in
    # them (no icon_theme key ends up in qt6ct.conf), so QIcon::fromTheme in
    # Qt apps (quickshell included) has no theme to search -- point it at
    # the same theme GTK uses above.
    # (Adwaita is no longer installed by gtk.iconTheme.package above, so point
    # Qt at the same Yaru variant rather than a theme that may not be present.)
    qt.qt5ctSettings.Appearance.icon_theme = iconTheme;
    qt.qt6ctSettings.Appearance.icon_theme = iconTheme;
  };
}
