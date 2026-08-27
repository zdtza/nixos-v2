{
  config,
  lib,
  pkgs,
  ...
}:

# Windows 11 in a container (dockurr/windows: KVM + QEMU inside Docker),
# reachable over RDP. Self-contained: import this file into any host's
# `imports` alongside home-manager's NixOS module, set `windows.user`, done
# — the launcher, desktop entry and icon for `cfg.user` come along with it
# (below, under `home-manager.users`), no separate home-manager module to
# wire up.
let
  cfg = config.windows;
  container = config.virtualisation.oci-containers.containers.windows;
in
{
  options.windows = {
    user = lib.mkOption {
      type = lib.types.str;
      description = ''
        Unix user allowed to start/stop/wipe the Windows container without a
        root password prompt (needed because the launcher is invoked from a
        desktop entry, where there is no terminal to answer sudo), the
        home-manager user the launcher/desktop entry are installed for, and
        the Windows account username, unless overridden below.
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

  config = {
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

    # Front end for the container above, installed for cfg.user via
    # home-manager. Four separate commands rather than one with flags:
    # nothing in windows-launch, windows-install or windows-stop can reach
    # the code that deletes the disk image. Only windows-remove touches it,
    # and the deletion itself lives in the root-owned unit above.
    home-manager.users.${cfg.user} =
      {
        config,
        pkgs,
        lib,
        ...
      }:
      let
        unit = "docker-windows.service";
        wipeUnit = "windows-wipe.service";
        host = "127.0.0.1";
        rdpPort = toString cfg.ports.rdp;
        webUrl = "http://127.0.0.1:${toString cfg.ports.web}";

        # Written once Windows genuinely answers RDP, and removed by
        # windows-remove. Only ever a cache: a live RDP handshake outranks
        # it, so a stale or missing marker can never block a working
        # Windows instance.
        marker = "${config.xdg.stateHome}/windows-vm/installed";

        helpers = ''
          notify() {
            notify-send \
              --app-name='Windows' \
              --icon=windows \
              --expire-time=2000 \
              "$@" || true
          }

          windows_running() {
            systemctl is-active --quiet ${unit}
          }

          mark_installed() {
            mkdir -p "$(dirname ${marker})"
            touch ${marker}
          }

          # A published docker port accepts TCP as soon as the container starts,
          # even with nothing listening inside the guest, so a plain connect
          # test reports "ready" for the entire install. Send an X.224
          # connection request and require a TPKT reply (version byte 3)
          # instead.
          rdp_ready() {
            reply=$(timeout 3 bash -c "
              exec 3<>/dev/tcp/${host}/${rdpPort} || exit 1
              printf '\x03\x00\x00\x13\x0e\xe0\x00\x00\x00\x00\x00\x01\x00\x08\x00\x03\x00\x00\x00' >&3
              head -c 4 <&3 | od -An -tx1
            " 2>/dev/null | tr -d ' \n')

            [[ $reply == 03* ]]
          }
        '';

        runtimeInputs = with pkgs; [
          bash
          coreutils
          libnotify
          systemd
        ];

        # Connect to Windows, starting it first if needed. No install, no
        # delete path.
        launch = pkgs.writeShellApplication {
          name = "windows-launch";
          runtimeInputs = runtimeInputs ++ [ pkgs.freerdp ];
          text = ''
            ${helpers}

            if ! windows_running; then
              systemctl start ${unit}
            fi

            deadline=$((SECONDS + 180))
            while ! rdp_ready; do
              if (( SECONDS >= deadline )); then
                notify 'Windows is not responding' 'Watch it at ${webUrl}'
                exit 1
              fi
              sleep 2
            done

            # Answering RDP proves it is installed, whatever the marker said.
            mark_installed

            exec xfreerdp \
              "/v:${host}:${rdpPort}" \
              "/u:${container.environment.USERNAME}" \
              "/p:${container.environment.PASSWORD}" \
              /cert:ignore \
              /dynamic-resolution \
              /sound \
              /microphone \
              +clipboard \
              +auto-reconnect \
              /wm-class:windows
          '';
        };

        # First-time setup. Starts the container and points at the web
        # viewer; the install itself is unattended and watched in the
        # browser, not here.
        install = pkgs.writeShellApplication {
          name = "windows-install";
          inherit runtimeInputs;
          text = ''
            ${helpers}

            if [[ -f ${marker} ]]; then
              notify 'Windows' 'Already installed, erase it first to reinstall.'
              exit 0
            fi

            if ! windows_running; then
              systemctl start ${unit}
            fi

            notify 'Installing Windows' 'Watch the progress at ${webUrl}'
          '';
        };

        # Shut Windows down. Refuses while Setup looks unfinished, because
        # stopping then throws the whole install away.
        stop = pkgs.writeShellApplication {
          name = "windows-stop";
          inherit runtimeInputs;
          text = ''
            ${helpers}

            if ! windows_running; then
              notify 'Windows' 'Already stopped.'
              exit 0
            fi

            # Nothing answering RDP and no install ever recorded is what an
            # in-progress Setup looks like. Until it finishes, dockur keeps
            # the install ISO first in the boot order, so a stop restarts it
            # from scratch.
            if ! rdp_ready && [[ ! -f ${marker} ]]; then
              notify 'Windows Setup is still running' 'Refusing to stop: it would restart the install.'
              exit 1
            fi

            notify 'Windows' 'Shutting down...'
            systemctl stop ${unit}
          '';
        };

        # The only command that destroys anything, and the only one that
        # cannot be triggered from a menu: it requires a terminal so the
        # confirmation is real.
        remove = pkgs.writeShellApplication {
          name = "windows-remove";
          inherit runtimeInputs;
          text = ''
            ${helpers}

            if [[ ! -t 0 ]]; then
              notify 'Run windows-remove in a terminal' 'It confirms before deleting the disk image.'
              exit 1
            fi

            read -r -p 'Erase Windows? This permanently deletes the disk image. [y/N] ' reply
            [[ $reply == [Yy]* ]] || exit 0

            systemctl start ${wipeUnit}
            rm -f ${marker}
            notify 'Windows erased' 'Run windows-install to set it up again.'
          '';
        };
      in
      {
        # Inlined rather than a sibling file, so the module is one
        # self-contained file when imported by another flake.
        home.file.".local/share/icons/hicolor/scalable/apps/windows.svg".source =
          pkgs.writeText "windows.svg" ''
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48">
              <g fill="#0078d4">
                <rect x="4" y="4" width="18" height="18" rx="1.5" />
                <rect x="26" y="4" width="18" height="18" rx="1.5" />
                <rect x="4" y="26" width="18" height="18" rx="1.5" />
                <rect x="26" y="26" width="18" height="18" rx="1.5" />
              </g>
            </svg>
          '';

        home.packages = [
          launch
          install
          stop
          remove
        ];

        xdg.desktopEntries.windows = {
          name = "Windows";
          genericName = "Windows 11";
          comment = "Windows 11 virtual machine";
          exec = lib.getExe launch;
          icon = "windows";
          categories = [ "System" ];
          terminal = false;
          type = "Application";
          settings.StartupWMClass = "windows";

          # No erase action: windows-remove is terminal-only by design.
          actions = {
            install = {
              name = "Install Windows";
              exec = lib.getExe install;
            };
            viewer = {
              name = "Web viewer";
              exec = "${pkgs.xdg-utils}/bin/xdg-open ${webUrl}";
            };
            shutdown = {
              name = "Shut down";
              exec = lib.getExe stop;
            };
          };
        };
      };
  };
}
