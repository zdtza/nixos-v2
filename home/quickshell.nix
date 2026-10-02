{
  pkgs,
  config,
  ...
}:

let
  colors = config.lib.stylix.colors.withHashtag;
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
      # themes/*/accent, same slot hyprland's active border and yazi's folder icons use (home/hyprland.nix, home/yazi.nix)
      accent = colors.${config.theme.current.accent};
      wallpaper = config.theme.current.wallpaper;
      monospace = config.stylix.fonts.monospace.name;
    }
  );

in
{
  # Quickshell reads the selected theme when it starts.
  xdg.configFile."quickshell-theme.json".source = themeJson;

  home = {
    # Pass the system time zone to Quickshell.
    sessionVariables.TZDIR = "/etc/zoneinfo";

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

  # starting the quickshell service on login after graphical session.
  systemd.user.services.quickshell = {
    Unit = {
      Description = "Quickshell desktop shell";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };

    Service = {
      Environment = [
        "TZDIR=${config.home.sessionVariables.TZDIR}"
        # Lock on every service start, including crash recovery.
        "QS_AUTOLOCK=1"
      ];
      ExecStart = "${pkgs.quickshell}/bin/quickshell";
      Restart = "on-failure";
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
