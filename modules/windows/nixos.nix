{
  config,
  lib,
  pkgs,
  ...
}:

# Windows 11 in a container (dockurr/windows: KVM + QEMU inside Docker),
# reachable over RDP. Self-contained: drop `nixosModules.windows` from this
# flake into any host, set `services.windows.enable = true` and `.user`,
# pair with `homeManagerModules.windows` for the launcher, done.
let
  cfg = config.services.windows;
in
{
  options.services.windows = {
    enable = lib.mkEnableOption "a dockurr/windows Windows 11 VM";

    user = lib.mkOption {
      type = lib.types.str;
      description = ''
        Unix user allowed to start/stop/wipe the Windows container without a
        root password prompt (needed because the launcher is invoked from a
        desktop entry, where there is no terminal to answer sudo), and the
        Windows account username, unless overridden below.
      '';
    };

    username = lib.mkOption {
      type = lib.types.str;
      default = cfg.user;
      description = "Windows account username. Defaults to `user`.";
    };

    password = lib.mkOption {
      type = lib.types.str;
      default = "windows";
      description = ''
        Windows account password. Stored in plaintext in the Nix store and
        in `docker inspect` output. Fine for a throwaway local VM; do not
        reuse a real password here.
      '';
    };

    ramSize = lib.mkOption {
      type = lib.types.str;
      default = "8G";
    };

    cpuCores = lib.mkOption {
      type = lib.types.str;
      default = "4";
    };

    diskSize = lib.mkOption {
      type = lib.types.str;
      default = "64G";
    };

    imageTag = lib.mkOption {
      type = lib.types.str;
      default = "6.05";
      description = "dockurr/windows image tag.";
    };

    storagePath = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/windows-vm";
      description = ''
        Persistent disk image location. Deliberately outside the Nix store
        and never touched by a rebuild.
      '';
    };

    ports = {
      web = lib.mkOption {
        type = lib.types.port;
        default = 8006;
        description = "Web viewer, needed to watch the first install.";
      };
      rdp = lib.mkOption {
        type = lib.types.port;
        default = 3389;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.docker = {
      enable = true;
      enableOnBoot = false;
    };

    virtualisation.oci-containers = {
      backend = "docker";
      containers.windows = {
        image = "dockurr/windows:${cfg.imageTag}";
        autoStart = false;

        environment = {
          VERSION = "11";
          RAM_SIZE = cfg.ramSize;
          CPU_CORES = cfg.cpuCores;
          DISK_SIZE = cfg.diskSize;
          USERNAME = cfg.username;
          PASSWORD = cfg.password;
          TZ = config.time.timeZone;
        };

        volumes = [ "${cfg.storagePath}:/storage" ];

        ports = [
          "127.0.0.1:${toString cfg.ports.web}:8006"
          "127.0.0.1:${toString cfg.ports.rdp}:3389/tcp"
          "127.0.0.1:${toString cfg.ports.rdp}:3389/udp"
        ];

        devices = [
          "/dev/kvm"
          "/dev/net/tun"
        ];
        capabilities.NET_ADMIN = true;
      };
    };

    systemd.tmpfiles.rules = [ "d ${cfg.storagePath} 0700 root root -" ];

    # Erases every trace of Windows: container, disk image, and pulled image.
    # Runs as a unit rather than through sudo so the launcher can trigger it
    # via the polkit rule below, instead of an unanswerable password prompt.
    systemd.services.windows-wipe = {
      description = "Erase Windows and its container image";
      serviceConfig = {
        Type = "oneshot";
        # Stopping Windows alone can use the full 300s shutdown budget.
        TimeoutStartSec = 600;
        ExecStart =
          let
            docker = "${config.virtualisation.docker.package}/bin/docker";
            image = config.virtualisation.oci-containers.containers.windows.image;
          in
          pkgs.writeShellScript "windows-wipe" ''
            set -eu

            systemctl stop docker-windows.service || true

            # Normally a no-op, since the container runs with --rm.
            ${docker} rm -f windows >/dev/null 2>&1 || true

            # Contents only: the directory keeps its 0700 root ownership.
            find ${cfg.storagePath} -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +

            ${docker} image rm -f ${image} >/dev/null 2>&1 || true
          '';
      };
    };

    security.polkit.enable = true;
    security.polkit.extraConfig = ''
      var windowsUnits = ["docker-windows.service", "windows-wipe.service"];
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            windowsUnits.indexOf(action.lookup("unit")) >= 0 &&
            subject.user == "${cfg.user}") {
          return polkit.Result.YES;
        }
      });
    '';
  };
}
