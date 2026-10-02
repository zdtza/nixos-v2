{ pkgs, ... }:

{
  home.packages = [ pkgs.hyprsunset ];

  # Start with a neutral transform; quickshell controls the night-light temperature over Hyprland IPC.
  systemd.user.services.hyprsunset = {
    Unit = {
      Description = "Hyprland blue-light filter";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "${pkgs.hyprsunset}/bin/hyprsunset --identity";
      Restart = "on-failure";
      RestartSec = 2;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
