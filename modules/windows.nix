{
  config,
  lib,
  pkgs,
  ...
}:

# Windows 11 via dockur/windows, managed from an RDP launcher.
let
  cfg = config.windows;
  stringOption =
    default:
    lib.mkOption {
      type = lib.types.str;
      inherit default;
    };
in
{
  options.windows = {
    user = lib.mkOption {
      type = lib.types.str;
      description = "User allowed to manage the Windows VM and receive its launchers.";
    };
    username = stringOption cfg.user;
    password = stringOption "windows";
    ramSize = stringOption "8G";
    cpuCores = stringOption "4";
    diskSize = stringOption "64G";
    imageTag = stringOption "6.05";

    sharePath = lib.mkOption {
      type = lib.types.path;
      default = "${config.users.users.${cfg.user}.home}/.windows";
      description = "Host directory exposed as the Windows Data share.";
    };
    storagePath = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/windows-vm";
      description = "Persistent VM disk directory.";
    };
    ports = {
      web = lib.mkOption {
        type = lib.types.port;
        default = 8006;
      };
      rdp = lib.mkOption {
        type = lib.types.port;
        default = 3389;
      };
    };
  };

  config = {
    virtualisation = {
      docker = {
        enable = true;
        enableOnBoot = false;
      };
      oci-containers = {
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
          volumes = [
            "${cfg.storagePath}:/storage"
            "${cfg.sharePath}:/data"
          ];
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
    };

    systemd = {
      tmpfiles.rules = [
        "d ${cfg.storagePath} 0700 root root -"
        "d ${cfg.sharePath} 0755 ${cfg.user} ${config.users.users.${cfg.user}.group} -"
      ];

      services.windows-wipe = {
        description = "Erase Windows and its container image";
        serviceConfig = {
          Type = "oneshot";
          TimeoutStartSec = 600;
          ExecStart = pkgs.writeShellScript "windows-wipe" ''
            set -eu
            ${pkgs.systemd}/bin/systemctl stop docker-windows.service || true
            ${config.virtualisation.docker.package}/bin/docker rm -f windows >/dev/null 2>&1 || true
            ${pkgs.findutils}/bin/find ${cfg.storagePath} -mindepth 1 -maxdepth 1 -exec ${pkgs.coreutils}/bin/rm -rf -- {} +
            ${config.virtualisation.docker.package}/bin/docker image rm -f ${config.virtualisation.oci-containers.containers.windows.image} >/dev/null 2>&1 || true
          '';
        };
      };
    };

    # Starting/stopping is passwordless; destructive removal authenticates.
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id != "org.freedesktop.systemd1.manage-units" ||
            subject.user != "${cfg.user}")
          return;

        var unit = action.lookup("unit");
        if (unit == "docker-windows.service")
          return polkit.Result.YES;
        if (unit == "windows-wipe.service")
          return polkit.Result.AUTH_ADMIN;
      });
    '';

    home-manager.users.${cfg.user} =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        unit = "docker-windows.service";
        wipeUnit = "windows-wipe.service";
        host = "127.0.0.1";
        rdpPort = toString cfg.ports.rdp;
        webUrl = "http://${host}:${toString cfg.ports.web}";
        marker = "${config.xdg.stateHome}/windows-vm/installed";

        helpers = ''
          notify() {
            notify-send --app-name=Windows --icon=windows --expire-time=2500 "$@" || true
          }
          running() {
            systemctl is-active --quiet ${unit}
          }
          mark_installed() {
            mkdir -p "$(dirname ${marker})"
            touch ${marker}
          }
          rdp_ready() {
            reply=$(timeout 3 bash -c "
              exec 3<>/dev/tcp/${host}/${rdpPort} || exit 1
              printf '\x03\x00\x00\x13\x0e\xe0\x00\x00\x00\x00\x00\x01\x00\x08\x00\x03\x00\x00\x00' >&3
              head -c 4 <&3 | od -An -tx1
            " 2>/dev/null | tr -d ' \n')
            [[ $reply == 03* ]]
          }
        '';

        baseInputs = with pkgs; [
          bash
          coreutils
          libnotify
          systemd
        ];
        mkApp =
          name: extraInputs: text:
          pkgs.writeShellApplication {
            inherit name text;
            runtimeInputs = baseInputs ++ extraInputs;
          };

        launch = mkApp "windows-launch" [ pkgs.freerdp ] ''
          ${helpers}
          running || systemctl start ${unit}

          deadline=$((SECONDS + 180))
          until rdp_ready; do
            if (( SECONDS >= deadline )); then
              notify 'Windows is not responding' 'Watch it at ${webUrl}'
              exit 1
            fi
            sleep 2
          done

          mark_installed
          exec xfreerdp \
            "/v:${host}:${rdpPort}" \
            "/u:${cfg.username}" \
            "/p:${cfg.password}" \
            -grab-keyboard \
            /cert:ignore \
            /dynamic-resolution \
            /sound \
            /microphone \
            +clipboard \
            +auto-reconnect \
            /wm-class:windows
        '';

        restart = mkApp "windows-restart" [ pkgs.procps launch ] ''
          ${helpers}
          notify 'Windows' 'Reconnecting...'
          pkill -x xfreerdp || true
          sleep 1
          exec windows-launch
        '';

        install = mkApp "windows-install" [ ] ''
          ${helpers}
          if [[ -f ${marker} ]]; then
            notify 'Windows' 'Already installed, erase it first to reinstall.'
            exit 0
          fi
          running || systemctl start ${unit}
          notify 'Installing Windows' 'Watch the progress at ${webUrl}'
        '';

        stop = mkApp "windows-stop" [ ] ''
          ${helpers}
          if ! running; then
            notify 'Windows' 'Already stopped.'
            exit 0
          fi
          if ! rdp_ready && [[ ! -f ${marker} ]]; then
            notify 'Windows Setup is still running' 'Refusing to stop: it would restart the install.'
            exit 1
          fi
          notify 'Windows' 'Shutting down...'
          systemctl stop ${unit}
        '';

        remove = mkApp "windows-remove" [ ] ''
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
      in
      {
        home = {
          packages = [
            launch
            restart
            install
            stop
            remove
          ];
          file.".local/share/icons/hicolor/scalable/apps/windows.svg".text = ''
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
              <path fill="#0078d4" d="M4 4h18v18H4zm22 0h18v18H26zM4 26h18v18H4zm22 0h18v18H26z"/>
            </svg>
          '';
        };

        xdg.desktopEntries.windows = {
          name = "Windows";
          genericName = "Windows 11";
          comment = "Windows 11 virtual machine";
          exec = lib.getExe launch;
          icon = "windows";
          categories = [ "System" ];
          settings.StartupWMClass = "windows";
          actions = {
            install = {
              name = "Install Windows";
              exec = lib.getExe install;
            };
            restart = {
              name = "Restart session";
              exec = lib.getExe restart;
            };
            viewer = {
              name = "Web viewer";
              exec = "${pkgs.xdg-utils}/bin/xdg-open ${webUrl}";
            };
            shutdown = {
              name = "Quit";
              exec = lib.getExe stop;
            };
          };
        };
      };
  };
}
