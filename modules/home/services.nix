{ config, pkgs, ... }:

let
  target = "graphical-session.target";

  # Started with the graphical session and restarted if it crashes.
  sessionService =
    {
      description,
      exec,
      after ? [ ],
      environment ? [ ],
    }:
    {
      Unit = {
        Description = description;
        PartOf = [ target ];
        After = [ target ] ++ after;
      };
      Service = {
        ExecStart = exec;
        Environment = environment;
        Restart = "on-failure";
        RestartSec = 2;
      };
      Install.WantedBy = [ target ];
    };
in
{
  systemd.user.services = {
    quickshell = sessionService {
      description = "Quickshell desktop shell";
      exec = "${pkgs.quickshell}/bin/quickshell";
      # Pass the system time zone to Quickshell.
      environment = [ "TZDIR=${config.home.sessionVariables.TZDIR}" ];
    };

    # Reads ~/.config/hypr/hypridle.conf (modules/home/hypridle.nix).
    hypridle = sessionService {
      description = "Hyprland idle manager";
      exec = "${pkgs.hypridle}/bin/hypridle";
    };

    # Start with a neutral transform; quickshell controls the night-light temperature over Hyprland IPC.
    hyprsunset = sessionService {
      description = "Hyprland blue-light filter";
      exec = "${pkgs.hyprsunset}/bin/hyprsunset --identity";
    };

    # Reads ~/.config/voxtype/config.toml (modules/home/voxtype.nix).
    voxtype = sessionService {
      description = "Voxtype voice-to-text daemon";
      exec = "${pkgs.voxtype-vulkan}/bin/voxtype daemon";
      after = [
        "pipewire.service"
        "pipewire-pulse.service"
      ];
    };

    # Binary comes from the host's system-level programs._1password-gui. --silent starts it in the tray.
    "1password" = sessionService {
      description = "1Password";
      exec = "/run/current-system/sw/bin/1password --silent";
    };

    # Caffeine blocks idle timeout actions only; lid handling is unconditional. Quickshell starts and stops it.
    stay-awake = {
      Unit = {
        Description = "Inhibit idle timeout actions while caffeine mode is enabled";
        PartOf = [ target ];
        After = [ target ];
      };
      Service = {
        ExecStart = "${pkgs.systemd}/bin/systemd-inhibit --what=idle --mode=block --who=Quickshell --why=Stay-awake ${pkgs.coreutils}/bin/sleep infinity";
        KillMode = "control-group";
      };
    };
  };
}
