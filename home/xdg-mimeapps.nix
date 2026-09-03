{ pkgs, ... }:

{
  xdg.mimeApps = {
    enable = true;
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
      "text/x-moc" = "code.desktop";
      "text/x-pascal" = "code.desktop";
      "text/x-tcl" = "code.desktop";
      "text/x-tex" = "code.desktop";
      "text/x-c" = "code.desktop";
      "text/x-c++" = "code.desktop";
      "application/x-shellscript" = "code.desktop";
    };
  };
}
