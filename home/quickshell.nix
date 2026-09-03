{
  pkgs,
  config,
  ...
}:

let
  colors = config.lib.stylix.colors.withHashtag;
  fonts = config.stylix.fonts;

  # stylix to quickshell bridge for colors and fonts
  stylixQmlModule = pkgs.linkFarm "quickshell-stylix-qml-module" {
    "Stylix/Theme.qml" = builtins.toFile "Theme.qml" ''
      pragma Singleton

      import QtQuick

      QtObject {
          readonly property color base00: "${colors.base00}"
          readonly property color base01: "${colors.base01}"
          readonly property color base02: "${colors.base02}"
          readonly property color base03: "${colors.base03}"
          readonly property color base04: "${colors.base04}"
          readonly property color base05: "${colors.base05}"
          readonly property color base0D: "${colors.base0D}"
          readonly property color base08: "${colors.base08}"
          readonly property url wallpaper: "file://${config.stylix.image}"

          readonly property string monospace: "${fonts.monospace.name}"
          readonly property string sansSerif: "${fonts.sansSerif.name}"
          readonly property int fontSize: 13
      }
    '';
    "Stylix/qmldir" = builtins.toFile "qmldir" ''
      module Stylix
      singleton Theme 1.0 Theme.qml
    '';
  };

  # notification for timer completion
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
    # set the shell env so we can run qs from any terminal for debugging
    QML2_IMPORT_PATH = stylixQmlModule;
    # default icon for legacy apps
    QS_FALLBACK_APP_ICON = "${pkgs.adwaita-icon-theme}/share/icons/Adwaita/symbolic/categories/applications-system-symbolic.svg";
    # passing quickshell the system time zone
    TZDIR = "/etc/zoneinfo";
  };

  # dependencies for the quickshell (mostly for the network panel stats)
  home.packages = with pkgs; [
    quickshell
    gawk
    iproute2
    iputils
    iw
    jq
    timerAlert
  ];

  # symlinking the quickshell folder
  home.file.".config/quickshell".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.src/nixos/config/quickshell";

  # starting the quickshell service on login after graphical session
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
