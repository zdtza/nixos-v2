{
  repoFile,
  pkgs,
  config,
  ...
}:

let
  colors = config.lib.stylix.colors.withHashtag;
  rawColors = config.lib.stylix.colors;
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
          readonly property color dark_background: "${colors.base01}"
          // Dim wash painted over the screen behind popups (#AARRGGBB).
          readonly property color overlay: "#b3${rawColors.base00}"
          readonly property color surface: "${colors.base02}"
          readonly property color border: "${colors.base03}"
          readonly property color muted: "${colors.base04}"
          readonly property color foreground: "${colors.base05}"
          readonly property color accent: "${colors.base0D}"
          readonly property color urgent: "${colors.base08}"
          readonly property color warning: "${colors.base0A}"
          readonly property color success: "${colors.base0B}"

          readonly property string fontFamily: "${fonts.monospace.name}"
          readonly property int fontSize: 13
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

  # Wrapped so `qs` / `quickshell` always resolve the Stylix module, whether run
  # by the service or by hand in a terminal. Avoids depending on session env.
  quickshell = pkgs.symlinkJoin {
    name = "quickshell-stylix";
    paths = [ pkgs.quickshell ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      for bin in qs quickshell; do
        wrapProgram $out/bin/$bin --prefix QML2_IMPORT_PATH : ${stylixQmlModule}
      done
    '';
  };
in
{
  home.packages = [ quickshell ];

  home.file.".config/quickshell".source = repoFile "dotfiles/quickshell";

  systemd.user.services.quickshell = {
    Unit = {
      Description = "Quickshell desktop shell";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "${quickshell}/bin/quickshell";
      Restart = "on-failure";
      RestartSec = 2;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
