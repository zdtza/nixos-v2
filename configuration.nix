{
  config,
  lib,
  pkgs,
  ...
}:

let
  localHosts = [
    "management-local.pmis.servicesseta.org.za"
    "partner-local.pmis.servicesseta.org.za"
    "learner-local.pmis.servicesseta.org.za"
  ];

  # Persistent Windows disk image. Deliberately outside the nix store
  # and never touched by a rebuild.
  windowsStorage = "/var/lib/windows-vm";
in
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # needed for web-app install and nix search
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  boot = {
    consoleLogLevel = 0;
    initrd = {
      verbose = false;
    };
    kernelParams = [
      "quiet"
      "loglevel=0"
      "udev.log_level=3"
      "systemd.show_status=true"
      "mem_sleep_default=deep"
    ];
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot = {
        enable = true;
        configurationLimit = 20; # only allow 20 builds to be cached
      };
    };
  };

  networking.hostName = "nixos"; # Define your hostname.

  # Set your time zone.
  time.timeZone = "Africa/Johannesburg";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_ZA.UTF-8";

  users.users."zdtza" = {
    isNormalUser = true;
    description = "Connor du Toit";
    shell = pkgs.fish;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "kvm"
      "docker"
      "onepassword"
      "onepassword-cli"
    ];
  };

  # registers fish in /etc/shells and sets up system-wide completions
  programs.fish.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # PAM policy used by Quickshell's secure Wayland session lock.
  security.pam.services.quickshell = { };

  # trust locally-issued mkcert dev certs (e.g. pmis management-portal) system-wide
  # so Chromium-based webapps (WhatsApp, etc.) and Firefox accept them without warnings.
  # need to copy this from ~/.local/share/mkcert/rootCA.pem to ./rootCA.pem
  security.pki.certificateFiles = [ ./rootCA.pem ];

  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  # lets dynamically linked prebuilt binaries run (nvim-treesitter's
  # tree-sitter-cli, mason.nvim LSP/formatter installs, etc.)
  programs.nix-ld.enable = true;

  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "zdtza" ];
  };

  # power-saver on battery, performance when plugged in
  services.upower.enable = true;

  services.tlp = {
    enable = true;
    # Expose TLP through the power-profiles D-Bus API. This keeps TLP as the
    # single power manager while allowing Quickshell's native PowerProfiles
    # service to select performance, balanced, and power-saver profiles.
    pd.enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      CPU_MIN_PERF_ON_AC = 0;
      CPU_MAX_PERF_ON_AC = 100;
      CPU_MIN_PERF_ON_BAT = 0;
      CPU_MAX_PERF_ON_BAT = 60; # Lower cap to save power on battery
    };
  };

  # Windows 11 in a container (dockurr/windows: KVM + QEMU inside Docker),
  # reachable over RDP. Started on demand from the app launcher, not at boot,
  # so it costs nothing while unused.
  virtualisation.docker = {
    enable = true;
    enableOnBoot = false;
  };

  virtualisation.oci-containers = {
    backend = "docker";
    containers.windows = {
      image = "dockurr/windows:6.05";
      autoStart = false;

      environment = {
        VERSION = "11";
        RAM_SIZE = "8G";
        CPU_CORES = "4";
        DISK_SIZE = "64G";
        USERNAME = "zdtza";
        # The base image runs QEMU with `-rtc base=localtime`, so the guest
        # clock follows the container's, which defaults to UTC.
        TZ = config.time.timeZone;
        # World-readable in /nix/store. Acceptable only because both ports below
        # are bound to loopback; switch to `environmentFiles` if that changes.
        PASSWORD = "windows";
      };

      volumes = [ "${windowsStorage}:/storage" ];

      ports = [
        "127.0.0.1:8006:8006" # web viewer, needed to watch the first install
        "127.0.0.1:3389:3389/tcp" # RDP
        "127.0.0.1:3389:3389/udp"
      ];

      devices = [
        "/dev/kvm"
        "/dev/net/tun"
      ];
      capabilities.NET_ADMIN = true;
    };
  };

  systemd.tmpfiles.rules = [ "d ${windowsStorage} 0700 root root -" ];

  # oci-containers hardcodes 120s. Windows needs far longer to flush and shut
  # down; being killed mid-update corrupts the disk image.
  systemd.services.docker-windows.serviceConfig.TimeoutStopSec = lib.mkForce 300;

  # Erases every trace of Windows: container, disk image, and pulled image.
  # Runs as a unit rather than through sudo so the launcher can trigger it via
  # the same polkit rule, instead of an unanswerable password prompt.
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
          find ${windowsStorage} -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +

          ${docker} image rm -f ${image} >/dev/null 2>&1 || true
        '';
    };
  };

  # Lets the desktop entry start/stop Windows without a root password prompt,
  # which would otherwise be unanswerable when launched from the app launcher.
  security.polkit = {
    enable = true;
    extraConfig = ''
      var windowsUnits = ["docker-windows.service", "windows-wipe.service"];
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            windowsUnits.indexOf(action.lookup("unit")) >= 0 &&
            subject.user == "zdtza") {
          return polkit.Result.YES;
        }
      });
    '';
  };

  environment.systemPackages = with pkgs; [
    # general apps
    nautilus
    firefox
    hyprland
    fzf
    eza
    yazi
    slurp
    brightnessctl
    vscode
    git
    grim
    claude-code
    wl-clipboard
    hyprpicker
    hyprpaper
    bluetui
    localsend
    pi-coding-agent
    wiremix
    btop
    impala
    chromium
    python3
    file
    font-awesome
    fastfetch
    audacity
    dotnet-sdk_10
    mkcert
    steam
    gnome-calculator
    libnotify

    # lazyvim runtime deps
    ripgrep
    fd
    gcc
    unzip
    lazygit
    nodejs

    # nix dev stuff
    nixfmt
    nixd
  ];

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    withUWSM = true;
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-termfilechooser
    ];
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # --- nvidia configuration section ---
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    nvidiaSettings = true;
    open = false;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    powerManagement.enable = true;
    moduleParams.nvidia.NVreg_TemporaryFilePath = "/var/tmp";
  };

  # systemd-rfkill can persist a previous soft-blocked Bluetooth state.
  # Force-unblock the controller before bluetoothd starts so powerOnBoot can
  # reliably turn it on after rebuilds/reboots.
  systemd.services.bluetooth-unblock = {
    description = "Unblock Bluetooth rfkill before bluetoothd starts";
    wantedBy = [ "multi-user.target" ];
    before = [ "bluetooth.service" ];
    after = [ "systemd-rfkill.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.util-linux}/bin/rfkill unblock bluetooth";
    };
  };

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  networking = {
    firewall = {
      # opening for local send
      allowedTCPPorts = [ 53317 ];
      allowedUDPPorts = [ 53317 ];
    };
    # any local hosts you want to point to
    hosts = {
      "127.0.0.1" = localHosts;
      "::1" = localHosts;
    };
    networkmanager = {
      enable = true;
      dns = "systemd-resolved";
      wifi = {
        backend = "wpa_supplicant";
        powersave = false;
      };
    };
  };

  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNS = [
        "1.1.1.1"
        "8.8.8.8"
      ];
      Domains = [ "~." ];
      FallbackDNS = [
        "1.0.0.1"
        "8.8.4.4"
      ];
    };
  };

  stylix = {
    enable = true;
    polarity = "dark";
    image = ./assets/wallpapers/winding-road.jpg;

    # Keep boot and virtual consoles on their default palette.
    targets.console.enable = false;

    cursor = {
      package = pkgs.adwaita-icon-theme;
      name = "Adwaita";
      size = 24;
    };

    # default tokyo night theme
    base16Scheme = {
      base00 = "#1a1b26"; # background
      base01 = "#13141c"; # dark_background
      base02 = "#292e42"; # selection
      base03 = "#414868"; # muted
      base04 = "#565f89"; # dark_foreground
      base05 = "#a9b1d6"; # foreground
      base06 = "#b4bee6"; # light_foreground
      base07 = "#c0caf5"; # bright_foreground
      base08 = "#f7768e"; # red
      base09 = "#eb927b"; # orange
      base0A = "#e0af68"; # yellow
      base0B = "#9ece6a"; # green
      base0C = "#449dab"; # cyan
      base0D = "#7aa2f7"; # blue
      base0E = "#ad8ee6"; # magenta
      base0F = "#75493d"; # brown
    };

    fonts = {
      sizes = {
        applications = 10;
        terminal = 12;
        desktop = 10;
        popups = 10;
      };

      serif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Serif";
      };

      sansSerif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Sans";
      };

      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font";
      };

      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
    };
  };

  system.stateVersion = "26.05";
}
