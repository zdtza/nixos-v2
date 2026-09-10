{ pkgs, ... }:

{
  home.packages = [ pkgs.hyprsunset ];

  # starting hyprsunset as an identity transform, quickshell drives it over hyprland ipc.
  # gamma_max 150 raises the ipc gamma ceiling above the default 100 so DisplayService
  # can push screen brightness past hardware max (see maxLevel there)
  systemd.user.services.hyprsunset = {
    Unit = {
      Description = "Hyprland blue-light filter";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "${pkgs.hyprsunset}/bin/hyprsunset --identity --gamma_max 150";
      Restart = "on-failure";
      RestartSec = 2;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
