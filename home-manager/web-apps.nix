{
  config,
  lib,
  pkgs,
  repoPath,
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
      # Test whether Chromium background throttling causes Teams screen shares
      # to drop to a lower-resolution stream after inactivity or occlusion.
      chromiumFlags = [
        "--disable-backgrounding-occluded-windows"
        "--disable-renderer-backgrounding"
        "--disable-background-timer-throttling"
      ];
      iconUrl = "https://www.google.com/s2/favicons?domain=https://teams.cloud.microsoft/&sz=256";
      iconHash = "sha256-uFtVcoGXHvPhaO1ngV3fYQMd/UPItRmnRDrwUuhlyWY=";
    }
    {
      id = "gmail";
      name = "Gmail";
      url = "https://mail.google.com/mail/u/0/#inbox";
      isolated = false;
      iconUrl = "https://www.google.com/s2/favicons?domain=https://mail.google.com/mail/u/0/&sz=256";
      iconHash = "sha256-uvp1erTkKXGuCXxFS5ZWm8fg4Sa0g7bdiT34YaClscM=";
    }
    {
      id = "whatsapp";
      name = "WhatsApp";
      url = "https://web.whatsapp.com/";
      isolated = false;
      iconUrl = "https://static.whatsapp.net/rsrc.php/yd/r/PfkSLByWV8O.webp";
      iconHash = "sha256-SOlK/v+ynGb16E3I307iR/g4wof4fLiWDL9n9OjT3Tc=";
    }
    {
      id = "chatgpt";
      name = "ChatGPT";
      url = "https://chatgpt.com/";
      isolated = false;
      iconUrl = "https://www.google.com/s2/favicons?domain=https://chatgpt.com/&sz=256";
      iconHash = "sha256-kma57MEuQyyD54Pd8NPplY4T7E6s20exD2F6zfXXAUY=";
    }
    {
      id = "packages";
      name = "NixOS Packages";
      url = "https://search.nixos.org/packages?channel=unstable";
      isolated = false;
      # Match nixos-manual.desktop exactly and let current icon theme resolve it.
      iconName = "nix-snowflake";
    }
    # WEBAPPS
  ];

  mkWebappCommand =
    command:
    pkgs.writeShellScriptBin command ''
      # Resolved from repo.nix rather than the working directory, so the command
      # works from anywhere instead of only inside the flake checkout.
      script="${repoPath}/bash/${command}.sh"
      [[ -f "$script" ]] || {
        echo "Missing $script. Is the config repo checked out at ${repoPath}?" >&2
        exit 1
      }
      exec ${lib.getExe pkgs.bash} "$script" "$@"
    '';
  webappInstall = mkWebappCommand "webapp-install";
  webappRemove = mkWebappCommand "webapp-remove";

  mkEntry =
    app:
    let
      profileFlag = lib.optionalString (app.isolated or false
      ) "--user-data-dir=${config.xdg.dataHome}/chromium-webapps/${app.id} ";
      chromiumFlags = lib.optionalString ((app.chromiumFlags or [ ]) != [ ]) (
        "${lib.concatStringsSep " " app.chromiumFlags} "
      );
      url = lib.replaceStrings [ "%" "\"" ] [ "%%" "\\\"" ] app.url;
      icon =
        if app ? iconName then
          app.iconName
        else
          let
            sourceIcon = pkgs.fetchurl {
              url = app.iconUrl;
              hash = app.iconHash;
              name = "${app.id}-icon-source";
            };
          in
          # Desktop launchers do not consistently detect formats when store paths
          # lack matching extensions. Normalize PNG, JPEG, WebP, GIF, ICO, and SVG
          # inputs to a static PNG with a truthful filename.
          pkgs.runCommand "${app.id}-icon.png" { } ''
            ${pkgs.imagemagick}/bin/magick "${sourceIcon}[0]" \
              -auto-orient -background none "PNG32:$out"
          '';
    in
    lib.nameValuePair app.id {
      name = app.name;
      comment = "${app.name} web app";

      exec = ''${pkgs.chromium}/bin/chromium ${profileFlag}${chromiumFlags}"--app=${url}"'';
      inherit icon;
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
