{ config, pkgs, ... }:

let
  localHosts = [
    "management-local.pmis.servicesseta.org.za"
    "partner-local.pmis.servicesseta.org.za"
    "learner-local.pmis.servicesseta.org.za"
  ];
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
      "onepassword"
      "onepassword-cli"
    ];
  };

  # registers fish in /etc/shells and sets up system-wide completions
  programs.fish.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # trust locally-issued mkcert dev certs (e.g. pmis management-portal) system-wide
  # so Chromium-based webapps (WhatsApp, etc.) and Firefox accept them without warnings.
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
    lazydocker
    btop
    impala
    chromium
    fuzzel
    python3
    file
    font-awesome
    fastfetch
    audacity
    dotnet-sdk_10
    mkcert

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

  xdg.portal.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];

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
    image = ./wallpapers/winding-road.jpg;

    cursor = {
      package = pkgs.adwaita-icon-theme;
      name = "Adwaita";
      size = 24;
    };

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
