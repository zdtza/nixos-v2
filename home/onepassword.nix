{
  # binary comes from the system-level programs._1password-gui (hosts/legion),
  # so no home.packages copy here. --silent starts it to the tray without a window.
  # Auto-unlock comes from the polkit rule in hosts/legion/default.nix plus the
  # app's own "unlock using system authentication" setting (settings.json is
  # HMAC-signed by the app, so it's toggled in the GUI, not declared here).
  systemd.user.services."1password" = {
    Unit = {
      Description = "1Password";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "/run/current-system/sw/bin/1password --silent";
      Restart = "on-failure";
      RestartSec = 5;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
