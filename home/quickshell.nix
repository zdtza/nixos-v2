{
  pkgs,
  config,
  ...
}:

let
  colors = config.lib.stylix.colors.withHashtag;
  rawColors = config.lib.stylix.colors;
  fonts = config.stylix.fonts;

  # Stylix-derived values can't live in the editable config dir, so they are
  # generated as a standalone QML module (`import Stylix` -> `Theme.*`) that is
  # put on QML2_IMPORT_PATH. Palette changes need a rebuild; everything else in
  # config/quickshell is hot-reloaded by quickshell itself.
  stylixQmlModule = pkgs.runCommand "quickshell-stylix-qml-module" { } ''
    mkdir -p $out/Stylix
    cat > $out/Stylix/Theme.qml <<'EOF'
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
        readonly property url wallpaper: "file://${config.stylix.image}"

        readonly property string fontFamily: "${fonts.monospace.name}"
        readonly property int fontSize: 13
    }
    EOF
    cat > $out/Stylix/qmldir <<'EOF'
    module Stylix
    singleton Theme 1.0 Theme.qml
    EOF
  '';

  timerAlert = pkgs.writeShellApplication {
    name = "qs-timer-alert";
    text = ''
      ${pkgs.libnotify}/bin/notify-send \
        --app-name="Quickshell Timer" \
        --urgency=critical \
        --icon=alarm-symbolic \
        --expire-time=10000 \
        "Timer complete" \
        "Countdown has elapsed." || true

      exec ${pkgs.pipewire}/bin/pw-play \
        ${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga
    '';
  };
in
{
  home.sessionVariables = {
    QML2_IMPORT_PATH = stylixQmlModule;
    QS_FALLBACK_APP_ICON = "${pkgs.adwaita-icon-theme}/share/icons/Adwaita/symbolic/categories/applications-system-symbolic.svg";
    TZDIR = "/etc/zoneinfo";
  };

  home.packages = with pkgs; [
    quickshell
    gawk
    iproute2
    iputils
    iw
    jq
    timerAlert
  ];

  home.file.".config/quickshell".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.src/nixos/config/quickshell";

  systemd.user.services.quickshell = {
    Unit = {
      Description = "Quickshell desktop shell";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };

    Service = {
      Environment = [
        "QML2_IMPORT_PATH=${stylixQmlModule}"
        "QS_FALLBACK_APP_ICON=${pkgs.adwaita-icon-theme}/share/icons/Adwaita/symbolic/categories/applications-system-symbolic.svg"
        "TZDIR=${config.home.sessionVariables.TZDIR}"
      ];
      ExecStart = "${pkgs.quickshell}/bin/quickshell";
      Restart = "on-failure";
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
