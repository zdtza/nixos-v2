{ pkgs, ... }:

let
  # nixpkgs' vscode only ships its icon at hicolor/1024x1024/apps, which
  # isn't a size bucket hicolor's index.theme declares (MaxSize=512), so
  # spec-compliant icon lookup never finds it. Re-expose the same file
  # under a declared bucket.
  vscodeIcon = "${pkgs.vscode}/share/icons/hicolor/1024x1024/apps/vscode.png";

  # yazi's nixpkgs package ships no icon at all, even though upstream has
  # one (assets/logo.png, referenced by their own assets/yazi.desktop).
  yaziIcon = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/sxyazi/yazi/main/assets/logo.png";
    hash = "sha256-ffAdaF1nJ9zxZfLeXZFF3tyonTjhj1JiCansY0armRU=";
  };
in
{
  # setting the icon theme
  gtk.iconTheme = {
    name = "Adwaita";
    package = pkgs.adwaita-icon-theme;
  };

  # symlink icons that are missing/unreachable from the packages themselves
  # into hicolor so standard icon-name lookup (Icon=vscode / Icon=yazi in
  # their .desktop files) resolves them.
  home.file = {
    ".local/share/icons/hicolor/256x256/apps/vscode.png".source = vscodeIcon;
    ".local/share/icons/hicolor/512x512/apps/yazi.png".source = yaziIcon;
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
