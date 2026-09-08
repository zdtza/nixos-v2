{
  pkgs,
  config,
  lib,
  ...
}:

let
  colors = config.lib.stylix.colors.withHashtag;
  fonts = config.stylix.fonts;

  # The wallpaper's path *in the repo*, not the /nix/store copy
  # config.stylix.image resolves to. components/WallpaperPicker.qml lists the
  # sibling files of this path to build its choices, and /nix/store's siblings
  # are the entire store; themes/<theme>/wallpapers is the real set (folder
  # name matches theme.name exactly, see themes/default.nix). It is also the
  # exact shape scripts/select-wallpaper.sh writes into this same file on a
  # live switch, so the value no longer changes form across `sw`.
  themes = (import ../themes).themes;
  wallpaperPath = "${config.home.homeDirectory}/.src/nixos/themes/"
    + "${config.theme.name}/wallpapers/${baseNameOf themes.${config.theme.name}.wallpaper}";

  # theme data for Quickshell, read at runtime by services/Theme.qml. Plain
  # JSON on purpose, not a generated QML module imported via QML2_IMPORT_PATH:
  # that path was a Nix store path that changed every theme switch, which
  # either forced a full quickshell respawn (re-triggering the lock screen's
  # autolock) or, pointed at through a stable symlink instead, silently never
  # reloaded at all -- a swapped symlink target isn't visible to a file
  # watcher watching the file that was actually opened. This file is
  # rewritten *in place* by the activation script below (same inode, real
  # IN_MODIFY), which a FileView{watchChanges:true} does actually pick up.
  themeJson = pkgs.writeText "quickshell-theme.json" (
    builtins.toJSON {
      inherit (colors)
        base00
        base01
        base02
        base03
        base04
        base05
        base06
        base07
        base08
        base09
        base0A
        base0B
        base0C
        base0D
        base0E
        base0F
        ;
      wallpaper = wallpaperPath;
      monospace = fonts.monospace.name;
      sansSerif = fonts.sansSerif.name;
    }
  );

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
  # `cp` (no --remove-destination) overwrites the destination's content in
  # place instead of unlink+recreate, so its inode -- and any inotify watch
  # on it -- survives across `sw`.
  home.activation.quickshellTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/.cache/quickshell"
    # first cp ever creates the file inheriting the Nix store source's
    # read-only mode -- force it writable before every copy, in place
    run touch "$HOME/.cache/quickshell/theme.json"
    run chmod u+w "$HOME/.cache/quickshell/theme.json"
    run cp ${themeJson} "$HOME/.cache/quickshell/theme.json"
  '';

  home.sessionVariables = {
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
        "QS_FALLBACK_APP_ICON=${pkgs.adwaita-icon-theme}/share/icons/Adwaita/symbolic/categories/applications-system-symbolic.svg"
        "TZDIR=${config.home.sessionVariables.TZDIR}"
        # locks in-process on startup (cold boot autologin, greeter login, or
        # a crash restart alike), see LockScreen.qml's Component.onCompleted.
        # Unset for manual `qs` debug runs from a terminal.
        "QS_AUTOLOCK=1"
      ];
      ExecStart = "${pkgs.quickshell}/bin/quickshell";
      Restart = "on-failure";
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
