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
    }
    {
      id = "google-drive";
      name = "Google Drive";
      url = "https://drive.google.com/drive/my-drive";
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
    }
    {
      id = "gmail";
      name = "Gmail";
      url = "https://mail.google.com/mail/u/0/#inbox";
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
    }
    {
      id = "packages";
      name = "NixOS Packages";
      url = "https://search.nixos.org/packages?channel=unstable";
      # matching nixos-manual.desktop exactly so the icon theme resolves it.
      iconName = "nix-snowflake";
    }
    {
      id = "google-calendar";
      name = "Google Calendar";
      url = "https://calendar.google.com/calendar/u/0/r";
    }
    {
      id = "claude";
      name = "Claude";
      url = "https://claude.ai/new";
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
      icon = app.iconName or (iconDir + "/${app.id}.png");
      isChromium = (app.browser or "firefox") == "chromium";
      urlParts = builtins.match "^[^:]+://([^/]+).*$" app.url;
      # Chromium app windows use this generated XWayland class. Quickshell's
      # desktop-entry lookup understands StartupWMClass and can then resolve the
      # custom icon instead of falling back to Chromium's icon.
      startupWMClass = app.startupWMClass or "chrome-${builtins.elemAt urlParts 0}__-Default";
      exec =
        if !isChromium then
          ''${pkgs.firefox}/bin/firefox "${url}"''
        else
          ''${pkgs.chromium}/bin/chromium ${profileFlag}${chromiumFlags}"--app=${url}"'';
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
