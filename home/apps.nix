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
      # exec = ''${pkgs.chromium}/bin/chromium ${profileFlag}"--app=${url}"'';
      exec = ''${pkgs.chromium}/bin/chromium ${profileFlag}"--app=${url}" "--auto-select-desktop-capture-source=Entire screen" --hide-scrollbars --use-fake-ui-for-media-stream --test-type'';
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
