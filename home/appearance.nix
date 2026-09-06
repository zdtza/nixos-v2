{ pkgs, config, ... }:

{
  # global color scheme for GTK apps, follows stylix polarity
  gtk.colorScheme = if config.stylix.polarity == "light" then "light" else "dark";

  # global icon theme
  gtk.iconTheme = {
    name = "Adwaita";
    package = pkgs.adwaita-icon-theme;
  };

  # mirrored into dconf too (programs.dconf.enable in modules/wayland.nix):
  # GTK3+/libadwaita apps subscribe to this over D-Bus and re-theme live,
  # settings.ini above only covers apps launched after the fact
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = if config.stylix.polarity == "light" then "prefer-light" else "prefer-dark";
    icon-theme = "Adwaita";
  };

  # stylix's qt target wires up qt6ct/qt5ct but never sets icon_theme in
  # them (no icon_theme key ends up in qt6ct.conf), so QIcon::fromTheme in
  # Qt apps (quickshell included) has no theme to search -- point it at
  # the same theme GTK uses above.
  qt.qt5ctSettings.Appearance.icon_theme = "Adwaita";
  qt.qt6ctSettings.Appearance.icon_theme = "Adwaita";
}