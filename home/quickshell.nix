{
  pkgs,
  config,
  lib,
  ...
}:

let
  colors = config.lib.stylix.colors.withHashtag;
  fonts = config.stylix.fonts;

  # WallpaperPicker lists sibling images, so use the repo path, not the store.
  themes = (import ../themes).themes;
  wallpaperPath = "${config.home.homeDirectory}/.src/nixos/themes/"
    + "${config.theme.name}/wallpapers/${baseNameOf themes.${config.theme.name}.wallpaper}";

  # Theme.qml watches this JSON in place. Replacing its inode or using a store
  # symlink would break live reload; restarting the shell would trigger autolock.
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
      # themes/*/accent, same slot hyprland's active border and yazi's folder
      # icons use (home/hyprland.nix, home/yazi.nix)
      accent = colors.${themes.${config.theme.name}.accent};
      wallpaper = wallpaperPath;
      monospace = fonts.monospace.name;
    }
  );

in
{
  home = {
  # Preserve the inode so Theme.qml's file watch survives activation.
  activation.quickshellTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/.cache/quickshell"
    # first cp ever creates the file inheriting the Nix store source's
    # read-only mode -- force it writable before every copy, in place
    run touch "$HOME/.cache/quickshell/theme.json"
    run chmod u+w "$HOME/.cache/quickshell/theme.json"
    run cp ${themeJson} "$HOME/.cache/quickshell/theme.json"
  '';

  sessionVariables = {
    # default icon for legacy apps
    QS_FALLBACK_APP_ICON = "${pkgs.adwaita-icon-theme}/share/icons/Adwaita/symbolic/categories/applications-system-symbolic.svg";
    # passing quickshell the system time zone
    TZDIR = "/etc/zoneinfo";
  };

  # Panel tools and timer sounds. pw-play comes from the system PipeWire package.
  packages = with pkgs; [
    quickshell
    gawk
    iproute2
    iputils
    iw
    jq
    libnotify
    sound-theme-freedesktop
  ];

  file.".config/quickshell".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.src/nixos/config/quickshell";
  };

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
        # Lock on every service start, including crash recovery. See LockScreen.qml.
        "QS_AUTOLOCK=1"
      ];
      ExecStart = "${pkgs.quickshell}/bin/quickshell";
      Restart = "on-failure";
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
