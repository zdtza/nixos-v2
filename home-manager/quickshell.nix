{
  repoFile,
  pkgs,
  config,
  ...
}:

let
  colors = config.lib.stylix.colors.withHashtag;
  fonts = config.stylix.fonts;

  # Stylix-derived values can't live in the editable dotfiles dir, so they are
  # generated as a standalone QML module (`import Stylix` -> `Theme.*`) that is
  # put on QML2_IMPORT_PATH. Palette changes need a rebuild; everything else in
  # dotfiles/quickshell is hot-reloaded by quickshell itself.
  stylixQml = pkgs.writeTextFile {
    name = "quickshell-stylix-qml";
    destination = "/Stylix/Theme.qml";
    text = ''
      pragma Singleton

      import QtQuick

      QtObject {
          readonly property color background: "${colors.base00}"
          readonly property color surface: "${colors.base02}"
          readonly property color border: "${colors.base03}"
          readonly property color muted: "${colors.base04}"
          readonly property color foreground: "${colors.base05}"
          readonly property color accent: "${colors.base0D}"
          readonly property color urgent: "${colors.base08}"
          readonly property color warning: "${colors.base0A}"
          readonly property color success: "${colors.base0B}"

          readonly property string fontFamily: "${fonts.monospace.name}"
          readonly property int fontSize: 12
          readonly property int fontSizeSmall: 10

          readonly property int barHeight: 32
          readonly property int paddingH: 10
          readonly property int spacing: 12
          readonly property int iconSize: 16
      }
    '';
  };

  stylixQmlModule = pkgs.runCommand "quickshell-stylix-qml-module" { } ''
    mkdir -p $out/Stylix
    cp ${stylixQml}/Stylix/Theme.qml $out/Stylix/Theme.qml
    cat > $out/Stylix/qmldir <<EOF
    module Stylix
    singleton Theme 1.0 Theme.qml
    EOF
  '';
in
{
  home.packages = [ pkgs.quickshell ];

  home.file.".config/quickshell".source = repoFile "dotfiles/quickshell";

  # Exported for the session too, so `quickshell` run by hand from a terminal
  # resolves the Stylix module the same way the service does.
  home.sessionVariables.QML2_IMPORT_PATH = "${stylixQmlModule}\${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}";

  systemd.user.services.quickshell = {
    Unit = {
      Description = "Quickshell desktop shell";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };

    Service = {
      Environment = [ "QML2_IMPORT_PATH=${stylixQmlModule}" ];
      ExecStart = "${pkgs.quickshell}/bin/quickshell";
      Restart = "on-failure";
      RestartSec = 2;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
