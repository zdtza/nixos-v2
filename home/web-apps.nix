{
  config,
  lib,
  pkgs,
  ...
}:

let
  # webapp-install.sh / webapp-remove.sh splice entries in/out above this marker.
  webApps = [
    {
      id = "youtube";
      name = "YouTube";
      url = "https://www.youtube.com/";
      browser = "firefox";
    }
    {
      id = "google-drive";
      name = "Google Drive";
      url = "https://drive.google.com/drive/my-drive";
      browser = "firefox";
    }
    {
      id = "llama-slack";
      name = "Llama Slack";
      url = "https://app.slack.com/client/TNZGA82FQ";
      browser = "chromium";
    }
    {
      id = "yt-music";
      name = "YT Music";
      url = "https://music.youtube.com/";
      browser = "firefox";
    }
    {
      id = "gmail";
      name = "Gmail";
      url = "https://mail.google.com/mail/u/0/#inbox";
      browser = "firefox";
    }
    {
      id = "whatsapp";
      name = "WhatsApp";
      url = "https://web.whatsapp.com/";
      browser = "chromium";
    }
    {
      id = "chatgpt";
      name = "ChatGPT";
      url = "https://chatgpt.com/";
      browser = "firefox";
    }
    {
      id = "packages";
      name = "NixOS Packages";
      url = "https://search.nixos.org/packages?channel=unstable";
      browser = "firefox";
      icon = "nix-snowflake";
    }
    {
      id = "google-calendar";
      name = "Google Calendar";
      url = "https://calendar.google.com/calendar/u/0/r";
      browser = "firefox";
    }
    {
      id = "claude";
      name = "Claude";
      url = "https://claude.ai/new";
      browser = "firefox";
    }
    {
      id = "onshape";
      name = "Onshape";
      url = "https://cad.onshape.com/documents?resourceType=resourceuserowner&nodeId=64b5b94853a57c4809702d57";
      browser = "chromium";
    }
    # WEBAPPS
  ];

  iconDir = ../assets/icons;

  # importing the custom install / remove scripts.
  mkWebappCommand =
    command:
    pkgs.writeShellScriptBin command ''
      export WEBAPP_MAGICK=${lib.getExe pkgs.imagemagick}
      exec ${lib.getExe pkgs.bash} ${config.home.homeDirectory}/.src/nixos/scripts/${command}.sh "$@"
    '';
  # generating the desktop entries for the web apps.
  mkEntry =
    app:
    let
      profileFlag = lib.optionalString (app.isolated or false
      ) "--user-data-dir=${config.xdg.dataHome}/chromium-webapps/${app.id} ";
      chromiumFlags = lib.optionalString (
        app ? chromiumFlags
      ) "${lib.concatStringsSep " " app.chromiumFlags} ";
      url = lib.replaceStrings [ "%" "\"" ] [ "%%" "\\\"" ] app.url;
      icon = app.icon or (iconDir + "/${app.id}.png");
      # Chromium app windows have a per-site class, allowing the workspace
      # indicator to match them to their desktop entry and custom icon. Entries
      # explicitly selecting Chromium retain that fix; all others use Firefox.
      browser = app.browser or "firefox";
      isChromium = browser == "chromium";
      isFirefox = browser == "firefox";
      urlParts = builtins.match "^[^:]+://([^/]+).*$" app.url;
      pathParts = builtins.match "^[^:]+://[^/]+(/[^?#]*).*" app.url;
      urlPath = if pathParts == null then "/" else builtins.elemAt pathParts 0;
      # Chromium includes the URL path in an app window's XWayland class:
      # chrome-<host>_<path-with-slashes-replaced-by-underscores>-Default.
      # Match that full class so Quickshell can locate the desktop entry icon.
      startupWMClass = app.startupWMClass or "chrome-${builtins.elemAt urlParts 0}_${lib.replaceStrings [ "/" ] [ "_" ] urlPath}-Default";
      exec =
        if isChromium then
          ''${pkgs.chromium}/bin/chromium ${profileFlag}${chromiumFlags}"--app=${url}"''
        else if isFirefox then
          # Open in the normal Firefox browser rather than an app-mode wrapper.
          ''${pkgs.firefox}/bin/firefox --new-tab "${url}"''
        else
          throw "Unsupported browser '${browser}' for web app '${app.id}'";
    in
    lib.nameValuePair app.id {
      name = app.name;
      comment = "${app.name} web app";

      inherit exec icon;
      categories = [ "Network" ];
      settings = lib.optionalAttrs isChromium {
        StartupWMClass = startupWMClass;
      };
    };
in
{
  xdg.desktopEntries = builtins.listToAttrs (map mkEntry webApps);

  home.packages = map mkWebappCommand [
    "webapp-install"
    "webapp-remove"
  ];
}
