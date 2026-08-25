{ pkgs, ... }:

# Single source of truth for default applications (browser, etc). Add new
# default-app assignments here rather than scattering xdg-mime/BROWSER
# settings across other modules.
let
  # shared-mime-info has no glob for *.code-workspace, so the file manager
  # can't tell what it is without this. Dropped into share/mime/packages,
  # xdg.mime's update-mime-database run (home-manager's xdg module) picks
  # it up automatically since it's on home.packages.
  codeWorkspaceMimeInfo = pkgs.runCommand "code-workspace-mime-info" { } ''
    mkdir -p $out/share/mime/packages
    cat > $out/share/mime/packages/x-code-workspace.xml <<'EOF'
    <?xml version="1.0" encoding="UTF-8"?>
    <mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
      <mime-type type="application/x-code-workspace">
        <comment>VS Code workspace</comment>
        <glob pattern="*.code-workspace"/>
      </mime-type>
    </mime-info>
    EOF
  '';
in
{
  home.packages = [ codeWorkspaceMimeInfo ];

  home.sessionVariables = {
    BROWSER = "firefox";
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "firefox.desktop";
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
      "application/pdf" = "firefox.desktop";

      # imv over chromium, which also claims these
      "image/png" = "imv.desktop";
      "image/jpeg" = "imv.desktop";
      "image/gif" = "imv.desktop";
      "image/webp" = "imv.desktop";
      "image/bmp" = "imv.desktop";
      "image/tiff" = "imv.desktop";
      "image/svg+xml" = "imv.desktop";

      # mpv is the sole claimant of these already, but pin explicitly so
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
    };
  };
}
