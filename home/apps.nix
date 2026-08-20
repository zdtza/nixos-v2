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
    {
      id = "gmail";
      name = "Gmail";
      url = "https://mail.google.com/mail/u/0/#inbox";
      isolated = false;
      iconUrl = "https://www.google.com/s2/favicons?domain=https://mail.google.com/mail/u/0/&sz=256";
      iconHash = "sha256-uvp1erTkKXGuCXxFS5ZWm8fg4Sa0g7bdiT34YaClscM=";
    }
    # WEBAPPS
  ];

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

  home.packages = [
    webappInstall
    webappRemove
  ];
}
