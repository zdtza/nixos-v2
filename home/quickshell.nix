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

  # Stylix-derived values can't live in the editable config dir, so they are
  # generated as a standalone QML module (`import Stylix` -> `Theme.*`) that is
  # put on QML2_IMPORT_PATH. Palette changes need a rebuild; everything else in
  # config/quickshell is hot-reloaded by quickshell itself.
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
          readonly property url wallpaper: "file://${config.stylix.image}"

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

  networkStatus = pkgs.writeShellApplication {
    name = "qs-network-status";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      iproute2
      iputils
      iw
      jq
    ];
    text = ''
      probe=1.1.1.1
      route_json="$(ip -j route get "$probe" 2>/dev/null || true)"
      [[ -n "$route_json" ]] || exit 0

      iface="$(jq -r '.[0].dev // ""' <<<"$route_json")"
      gateway="$(jq -r '.[0].gateway // ""' <<<"$route_json")"
      address="$(jq -r '.[0].prefsrc // ""' <<<"$route_json")"
      [[ -n "$iface" ]] || exit 0

      prefix="$(ip -j addr show "$iface" | jq -r '.[0].addr_info[]? | select(.family == "inet") | .prefixlen // ""' | head -n1)"
      printf 'iface\t%s\n' "$iface"
      printf 'ip\t%s\n' "$address"
      printf 'prefix\t%s\n' "$prefix"
      printf 'gateway\t%s\n' "$gateway"

      [[ -r "/sys/class/net/$iface/statistics/rx_bytes" ]] && printf 'rx_bytes\t%s\n' "$(<"/sys/class/net/$iface/statistics/rx_bytes")"
      [[ -r "/sys/class/net/$iface/statistics/tx_bytes" ]] && printf 'tx_bytes\t%s\n' "$(<"/sys/class/net/$iface/statistics/tx_bytes")"

      if [[ -d "/sys/class/net/$iface/wireless" ]]; then
        printf 'type\twifi\n'
        link="$(iw dev "$iface" link 2>/dev/null || true)"
        [[ -n "$link" ]] && {
          printf 'ssid\t%s\n' "$(awk '/SSID:/ { sub(/.*SSID: /, ""); print; exit }' <<<"$link")"
          printf 'freq\t%s\n' "$(awk '/freq:/ { print $2; exit }' <<<"$link")"
          printf 'bitrate\t%s %s\n' "$(awk '/tx bitrate:/ { print $3; exit }' <<<"$link")" "$(awk '/tx bitrate:/ { print $4; exit }' <<<"$link")"
        }
      else
        printf 'type\tethernet\n'
        [[ -r "/sys/class/net/$iface/speed" ]] && printf 'speed\t%s\n' "$(<"/sys/class/net/$iface/speed")"
      fi

      ping_ms() {
        LC_ALL=C ping -n -c 1 -W 1 "$1" 2>/dev/null | awk -F'time[=<]' '/time[=<]/ { split($2, p, " "); print p[1]; exit }'
      }
      [[ -n "$gateway" ]] && printf 'router_ping_ms\t%s\n' "$(ping_ms "$gateway")"
      printf 'internet_ping_ms\t%s\n' "$(ping_ms "$probe")"
    '';
  };

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
  home.packages = [
    pkgs.quickshell
    networkStatus
    timerAlert
  ];

  home.file.".config/quickshell".source = repoFile "config/quickshell";

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
      ];
      ExecStart = "${pkgs.quickshell}/bin/quickshell";
      Restart = "on-failure";
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
