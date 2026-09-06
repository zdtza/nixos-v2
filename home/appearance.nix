{ pkgs, config, ... }:

{
  # global color scheme for GTK apps, follows stylix polarity
  gtk.colorScheme = if config.stylix.polarity == "light" then "light" else "dark";

  # global icon theme
  gtk.iconTheme = {
    name = "Adwaita";
    package = pkgs.adwaita-icon-theme;
  };

  # stylix's qt target wires up qt6ct/qt5ct but never sets icon_theme in
  # them (no icon_theme key ends up in qt6ct.conf), so QIcon::fromTheme in
  # Qt apps (quickshell included) has no theme to search -- point it at
  # the same theme GTK uses above.
  qt.qt5ctSettings.Appearance.icon_theme = "Adwaita";
  qt.qt6ctSettings.Appearance.icon_theme = "Adwaita";
}