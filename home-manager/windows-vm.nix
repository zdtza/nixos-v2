{
  config,
  pkgs,
  lib,
  osConfig,
  repoFile,
  ...
}:

# Front end for the `dockurr/windows` container defined in configuration.nix.
#
# Four separate commands rather than one with flags: nothing in windows-launch,
# windows-install or windows-stop can reach the code that deletes the disk
# image. Only windows-remove touches it, and the deletion itself lives in a
# root-owned systemd unit.
let
  container = osConfig.virtualisation.oci-containers.containers.windows;

  unit = "docker-windows.service";
  wipeUnit = "windows-vm-wipe.service";
  host = "127.0.0.1";
  rdpPort = "3389";
  webUrl = "http://127.0.0.1:8006";

  # Written once Windows genuinely answers RDP, and removed by windows-remove.
  # Only ever a cache: a live RDP handshake outranks it, so a stale or missing
  # marker can never block a working VM.
  marker = "${config.xdg.stateHome}/windows-vm/installed";

  helpers = ''
    notify() {
      notify-send --app-name='Windows VM' --icon=windows-vm "$@" || true
    }

    vm_running() {
      systemctl is-active --quiet ${unit}
    }

    mark_installed() {
      mkdir -p "$(dirname ${marker})"
      touch ${marker}
    }

    # A published docker port accepts TCP as soon as the container starts, even
    # with nothing listening inside the guest, so a plain connect test reports
    # "ready" for the entire install. Send an X.224 connection request and
    # require a TPKT reply (version byte 3) instead.
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

  # Connect to the VM, starting it first if needed. No install, no delete path.
  launch = pkgs.writeShellApplication {
    name = "windows-launch";
    runtimeInputs = runtimeInputs ++ [ pkgs.freerdp ];
    text = ''
      ${helpers}

      notify 'Windows' 'Connecting to virtual machine...'

      if ! vm_running; then
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
        /wm-class:windows-vm
    '';
  };

  # First-time setup. Starts the container and points at the web viewer; the
  # install itself is unattended and watched in the browser, not here.
  install = pkgs.writeShellApplication {
    name = "windows-install";
    inherit runtimeInputs;
    text = ''
      ${helpers}

      if [[ -f ${marker} ]]; then
        notify 'Windows' 'Windows is already installed, erase it first to reinstall.'
        exit 0
      fi

      if ! vm_running; then
        systemctl start ${unit}
      fi

      notify 'Installing Windows' 'Watch the progress at ${webUrl}'
    '';
  };

  # Shut the VM down. Refuses while Setup looks unfinished, because stopping
  # then throws the whole install away.
  stop = pkgs.writeShellApplication {
    name = "windows-stop";
    inherit runtimeInputs;
    text = ''
      ${helpers}

      if ! vm_running; then
        notify 'Windows' 'Already stopped.'
        exit 0
      fi

      # Nothing answering RDP and no install ever recorded is what an
      # in-progress Setup looks like. Until it finishes, dockur keeps the
      # install ISO first in the boot order, so a stop restarts it from scratch.
      if ! rdp_ready && [[ ! -f ${marker} ]]; then
        notify 'Windows Setup is still running' 'Refusing to stop: it would restart the install.'
        exit 1
      fi

      notify 'Windows' 'Shutting down virtual machine...'
      systemctl stop ${unit}
    '';
  };

  # The only command that destroys anything, and the only one that cannot be
  # triggered from a menu: it requires a terminal so the confirmation is real.
  remove = pkgs.writeShellApplication {
    name = "windows-remove";
    inherit runtimeInputs;
    text = ''
      ${helpers}

      if [[ ! -t 0 ]]; then
        notify 'Run windows-remove in a terminal' 'It confirms before deleting the disk image.'
        exit 1
      fi

      read -r -p 'Erase the Windows VM? This permanently deletes the disk image. [y/N] ' reply
      [[ $reply == [Yy]* ]] || exit 0

      systemctl start ${wipeUnit}
      rm -f ${marker}
      notify 'Windows VM erased' 'Run windows-install to set it up again.'
    '';
  };
in
{
  # Installed under hicolor as a themed name rather than referenced by path, so
  # the launcher resolves it the same way it resolves any other app icon.
  home.file.".local/share/icons/hicolor/scalable/apps/windows-vm.svg".source =
    repoFile "dotfiles/icons/windows-vm.svg";

  home.packages = [
    launch
    install
    stop
    remove
  ];

  xdg.desktopEntries.windows-vm = {
    name = "Windows";
    genericName = "Windows 11 VM";
    comment = "Connect to the Windows VM over RDP";
    exec = lib.getExe launch;
    icon = "windows-vm";
    categories = [ "System" ];
    terminal = false;
    type = "Application";
    settings.StartupWMClass = "windows-vm";

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
}
