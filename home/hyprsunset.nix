{ pkgs, ... }:

let
  package = pkgs.hyprsunset;
in
{
  home.packages = [ package ];

  # Keep hyprsunset available as an identity transform. Quickshell restores
  # persisted enablement and color temperature through Hyprland IPC.
  systemd.user.services.hyprsunset = {
    Unit = {
      Description = "Hyprland blue-light filter";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "${package}/bin/hyprsunset --identity";
      Restart = "on-failure";
      RestartSec = 2;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
