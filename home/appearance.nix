{ pkgs, ... }:

{
  # global color scheme for GTK apps (need to align with stylix polarity later)
  gtk.colorScheme = "dark";

  # global icon theme
  gtk.iconTheme = {
    name = "Adwaita";
    package = pkgs.adwaita-icon-theme;
  };
}