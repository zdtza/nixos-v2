{
  # Binary comes from the host's system-level programs._1password-gui, so no home.packages copy is needed. --silent starts it in the tray.
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
