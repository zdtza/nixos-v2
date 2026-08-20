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
      isolated = false;
      iconUrl = "https://www.google.com/s2/favicons?domain=https://www.youtube.com/&sz=256";
      iconHash = "sha256-y2rbGYQ7ZFvCJxgfUnRvAemo/abBEzjKwjxZd8fSOGw=";
    }
    {
      id = "google-drive";
      name = "Google Drive";
      url = "https://drive.google.com/drive/my-drive";
      isolated = false;
      iconUrl = "https://www.google.com/s2/favicons?domain=https://drive.google.com/drive/my-drive&sz=256";
      iconHash = "sha256-Q2CC+4/ZmvKJ1CPQqRPlUWR2lo7PvyMsZTPXAMxpSq4=";
    }
    {
      id = "llama-slack";
      name = "Llama Slack";
      url = "https://app.slack.com/client/TNZGA82FQ";
      isolated = false;
      iconUrl = "https://www.google.com/s2/favicons?domain=https://app.slack.com/client/TNZGA82FQ&sz=256";
      iconHash = "sha256-3vONfw6TIFUEiBaCgZTV6voOvziOTzYs/wnJ1+6cmos=";
    }
    {
      id = "yt-music";
      name = "YT Music";
      url = "https://music.youtube.com/";
      isolated = false;
      iconUrl = "https://www.google.com/s2/favicons?domain=https://music.youtube.com/&sz=256";
      iconHash = "sha256-f5M74vVmAmIrigDa0PWVPvZr88RJXLqKrTcqt8T9/Fs=";
    }
    {
      id = "teams";
      name = "Teams";
      url = "https://teams.cloud.microsoft/";
      isolated = true;
      iconUrl = "https://www.google.com/s2/favicons?domain=https://teams.cloud.microsoft/&sz=256";
      iconHash = "sha256-uFtVcoGXHvPhaO1ngV3fYQMd/UPItRmnRDrwUuhlyWY=";
    }
    {
      id = "whatsapp";
      name = "WhatsApp";
      url = "https://web.whatsapp.com/";
      isolated = false;
      iconUrl = "https://static.whatsapp.net/rsrc.php/yI/r/EoOh62-jiPS.webp";
      iconHash = "sha256-zwMr79bB+CS+6pls2+77lK4WBlBDgjXiUCK4rnRRREw=";
    }
    # WEBAPPS
  ];

  # Expose scripts/webapp-{install,remove}.sh on PATH. They locate the repo
  # via BASH_SOURCE, so keep them as thin execs into the real files rather
  # than copying script contents into the store.
  webappInstall = pkgs.writeShellScriptBin "webapp-install" ''
    exec "${config.home.homeDirectory}/.config/Nixodus/scripts/webapp-install.sh" "$@"
  '';
  webappRemove = pkgs.writeShellScriptBin "webapp-remove" ''
    exec "${config.home.homeDirectory}/.config/Nixodus/scripts/webapp-remove.sh" "$@"
  '';

  mkEntry =
    app:
    let
      profileFlag = lib.optionalString (app.isolated or false
      ) "--user-data-dir=${config.xdg.dataHome}/chromium-webapps/${app.id} ";
      url = lib.replaceStrings [ "%" "\"" ] [ "%%" "\\\"" ] app.url;
    in
    lib.nameValuePair app.id {
      name = app.name;
      comment = "${app.name} web app";
      # extra flags to make the chromium screen sharing experience seemless (may break!)
      # Desktop Entry Spec requires quotes to wrap a whole argument, not
      # just the value inside it (fuzzel enforces this and silently refuses
      # to launch entries that violate it).
      # exec = ''${pkgs.chromium}/bin/chromium ${profileFlag}"--app=${url}" "--auto-select-desktop-capture-source=Entire screen" --hide-scrollbars --use-fake-ui-for-media-stream --test-type'';

      exec = ''${pkgs.chromium}/bin/chromium ${profileFlag}"--app=${url}"'';
      icon = pkgs.fetchurl {
        url = app.iconUrl;
        hash = app.iconHash;
        name = "${app.id}-icon.png";
      };
      categories = [ "Network" ];
      terminal = false;
      type = "Application";
    };
in
{
  xdg.desktopEntries = builtins.listToAttrs (map mkEntry webApps);

  # making the scripts visible in bin
  home.packages = [
    webappInstall
    webappRemove
  ];
}
