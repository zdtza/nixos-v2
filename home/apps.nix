{ config, lib, pkgs, ... }:

let
  # webapp-install.sh / webapp-remove.sh splice entries in/out above this marker.
  webApps = [
    # WEBAPPS
  ];

  mkEntry = app:
    let
      profileFlag = lib.optionalString (app.private or false)
        "--user-data-dir=${config.xdg.dataHome}/chromium-webapps/${app.id} ";
      url = lib.replaceStrings [ "%" "\"" ] [ "%%" "\\\"" ] app.url;
    in
    lib.nameValuePair app.id {
      name = app.name;
      comment = "${app.name} web app";
      exec = ''${pkgs.chromium}/bin/chromium ${profileFlag}--app="${url}" --hide-scrollbars'';
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
}
