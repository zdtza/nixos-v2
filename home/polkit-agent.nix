{ pkgs, ... }:

# Hyprland ships no polkit agent of its own. Without one, udisks2 auth
# prompts (mounting/unlocking internal drives, gvfs, etc.) have nothing to
# render and silently fail.
{
  systemd.user.services.polkit-agent = {
    Unit = {
      Description = "Polkit authentication agent";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent";
      Restart = "on-failure";
      RestartSec = 2;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
