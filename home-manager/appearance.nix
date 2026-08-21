{ pkgs, ... }:

{
  # setting the icon theme
  gtk.iconTheme = {
    name = "Adwaita";
    package = pkgs.adwaita-icon-theme;
  };

  # ordering the file pickers / explorers all the same
  dconf.enable = true;
  dconf.settings = {
    "org/gnome/desktop/interface".icon-theme = "Adwaita";

    "org/gnome/nautilus/preferences" = {
      default-sort-order = "name";
      default-sort-in-reverse-order = false;
    };

    "org/gtk/gtk4/settings/file-chooser" = {
      sort-column = "name";
      sort-order = "ascending";
      sort-directories-first = true;
    };

    "org/gtk/settings/file-chooser" = {
      sort-column = "name";
      sort-order = "ascending";
      sort-directories-first = true;
    };
  };
}
