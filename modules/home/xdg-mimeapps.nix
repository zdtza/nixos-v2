{ lib, ... }:

let
  defaultApplications = {
    "text/html" = "firefox.desktop";
    "x-scheme-handler/http" = "firefox.desktop";
    "x-scheme-handler/https" = "firefox.desktop";
    "x-scheme-handler/file" = "code.desktop";
    "application/pdf" = "firefox.desktop";
    "inode/directory" = "org.gnome.Nautilus.desktop";

    "image/png" = "imv.desktop";
    "image/jpeg" = "imv.desktop";
    "image/gif" = "imv.desktop";
    "image/webp" = "imv.desktop";
    "image/bmp" = "imv.desktop";
    "image/tiff" = "imv.desktop";
    "image/svg+xml" = "imv.desktop";

    "video/mp4" = "mpv.desktop";
    "video/x-matroska" = "mpv.desktop";
    "video/webm" = "mpv.desktop";
    "video/quicktime" = "mpv.desktop";
    "video/x-msvideo" = "mpv.desktop";
    "audio/mpeg" = "mpv.desktop";
    "audio/flac" = "mpv.desktop";
    "audio/ogg" = "mpv.desktop";
    "audio/wav" = "mpv.desktop";
    "audio/mp4" = "mpv.desktop";

    "application/x-code-workspace" = "code.desktop";

    "text/english" = "code.desktop";
    "text/plain" = "code.desktop";
    "text/x-makefile" = "code.desktop";
    "text/x-c++hdr" = "code.desktop";
    "text/x-c++src" = "code.desktop";
    "text/x-chdr" = "code.desktop";
    "text/x-csrc" = "code.desktop";
    "text/x-java" = "code.desktop";
    "text/x-qml" = "code.desktop";
    "text/x-moc" = "code.desktop";
    "text/x-pascal" = "code.desktop";
    "text/x-tcl" = "code.desktop";
    "text/x-tex" = "code.desktop";
    "text/x-c" = "code.desktop";
    "text/x-c++" = "code.desktop";
    "application/x-shellscript" = "code.desktop";

    # .ts/.tsx aren't recognised as typescript by shared-mime-info, they collide with unrelated formats and were falling through to firefox.
    "text/vnd.trolltech.linguist" = "code.desktop";
    "application/x-tiled-tsx" = "code.desktop";
    "application/typescript" = "code.desktop";
  };
in
{
  # Declared defaults go in the data-dir mimeapps.list, which lookups consult
  # only after ~/.config/mimeapps.list. That leaves the config-dir file an
  # ordinary writable file: defaults chosen in Nautilus (Open With > Set as
  # Default) are saved there and override these, instead of failing against a
  # read-only store symlink as they do with xdg.mimeApps.
  xdg.dataFile."applications/mimeapps.list".text = lib.generators.toINI { } {
    "Default Applications" = defaultApplications;
  };
}
