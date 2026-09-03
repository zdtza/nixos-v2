{ pkgs, config, ... }:

{
  # global color scheme for GTK apps, follows stylix polarity
  gtk.colorScheme = if config.stylix.polarity == "light" then "light" else "dark";

  # global icon theme
  gtk.iconTheme = {
    name = "Adwaita";
    package = pkgs.adwaita-icon-theme;
  };
}