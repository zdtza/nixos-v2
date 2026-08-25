{ pkgs, ... }:

{
  # Stylix's gtk target never sets `gtk.colorScheme`; that's only done by its
  # gnome/kde targets, neither of which apply on this Hyprland session. Without
  # it, gtk-application-prefer-dark-theme / color-scheme are absent from
  # settings.ini, so adw-gtk3 renders widgets (buttons, native dialogs like
  # VS Code's "save changes" prompt) with light-theme assets on top of
  # stylix's dark color overrides -> washed-out, low-contrast controls.
  gtk.colorScheme = "dark";

  # adw-gtk3 ships an asymmetric `decoration { border-radius: 15px 15px 0 0; }`
  # rule (rounded top, square bottom - meant for windows with a headerbar
  # owning the rounded top edge). Chromium/Electron's GTK theme integration
  # reads that radius to shape its own window surface. VS Code's native
  # dialogs (e.g. the "save changes" prompt) have no headerbar, so Chromium
  # only carves the corner it's responsible for - the bottom two corners -
  # into real alpha-transparent pixels, leaving the top square. Hyprland's
  # blur xray then bleeds the desktop through those bottom corners. Zero the
  # radius so no corner gets cut.
  stylix.targets.gtk.extraCss = ''
    decoration, messagedialog.csd decoration, .csd.popup decoration, tooltip.csd decoration {
      border-radius: 0;
    }
  '';

  # setting the icon theme
  gtk.iconTheme = {
    name = "Adwaita";
    package = pkgs.adwaita-icon-theme;
  };

  # # ordering the file pickers / explorers all the same
  # dconf.enable = true;
  # dconf.settings = {
  #   "org/gnome/desktop/interface".icon-theme = "Adwaita";

  #   "org/gnome/nautilus/preferences" = {
  #     default-sort-order = "name";
  #     default-sort-in-reverse-order = false;
  #   };

  #   "org/gtk/gtk4/settings/file-chooser" = {
  #     sort-column = "name";
  #     sort-order = "ascending";
  #     sort-directories-first = true;
  #   };

  #   "org/gtk/settings/file-chooser" = {
  #     sort-column = "name";
  #     sort-order = "ascending";
  #     sort-directories-first = true;
  #   };
  # };
}
