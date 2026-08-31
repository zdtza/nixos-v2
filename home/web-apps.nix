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
    }
    {
      id = "google-drive";
      name = "Google Drive";
      url = "https://drive.google.com/drive/my-drive";
      isolated = false;
    }
    {
      id = "llama-slack";
      name = "Llama Slack";
      url = "https://app.slack.com/client/TNZGA82FQ";
      isolated = false;
    }
    {
      id = "yt-music";
      name = "YT Music";
      url = "https://music.youtube.com/";
      isolated = false;
    }
    {
      id = "gmail";
      name = "Gmail";
      url = "https://mail.google.com/mail/u/0/#inbox";
      isolated = false;
    }
    {
      id = "whatsapp";
      name = "WhatsApp";
      url = "https://web.whatsapp.com/";
      isolated = false;
    }
    {
      id = "chatgpt";
      name = "ChatGPT";
      url = "https://chatgpt.com/";
      isolated = false;
    }
    {
      id = "packages";
      name = "NixOS Packages";
      url = "https://search.nixos.org/packages?channel=unstable";
      isolated = false;
      # Match nixos-manual.desktop exactly and let current icon theme resolve it.
      iconName = "nix-snowflake";
    }
    {
      id = "google-calendar";
      name = "Google Calendar";
      url = "https://calendar.google.com/calendar/u/0/r";
      isolated = false;
    }
    {
      id = "claude";
      name = "Claude";
      url = "https://claude.ai/new";
      isolated = false;
    }
    {
      id = "onshape";
      name = "Onshape";
      url = "https://cad.onshape.com/documents?resourceType=resourceuserowner&nodeId=64b5b94853a57c4809702d57";
      isolated = false;
    }
    # WEBAPPS
  ];

  iconDir = ../assets/icons;

  mkWebappCommand =
    command:
    pkgs.writeShellScriptBin command ''
      # Resolved from repo.nix rather than the working directory, so the command
      # works from anywhere instead of only inside the flake checkout.
      script="${repoPath}/scripts/${command}.sh"
      [[ -f "$script" ]] || {
        echo "Missing $script. Is the config repo checked out at ${repoPath}?" >&2
        exit 1
      }
      export WEBAPP_MAGICK=${lib.getExe pkgs.imagemagick}
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
      icon = if app ? iconName then app.iconName else iconDir + "/${app.id}.png";
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
