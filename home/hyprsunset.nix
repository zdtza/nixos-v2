{ pkgs, ... }:

{
  home.packages = [ pkgs.hyprsunset ];

  # starting hyprsunset as an identity transform, quickshell drives it over hyprland ipc
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
