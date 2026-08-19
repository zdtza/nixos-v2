{ ... }:

{
  flake.nixosModules.hyprland =
    { pkgs, ... }:
    {
      # No display manager - launch `Hyprland` from a TTY after login.
      programs.hyprland.enable = true;

      xdg.portal.enable = true;
      xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];

      hardware.graphics.enable = true;

      security.rtkit.enable = true;
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        pulse.enable = true;
      };
    };
}
