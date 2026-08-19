{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
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

  # Enable networking
  

  # Set your time zone.
  time.timeZone = "Africa/Johannesburg";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_ZA.UTF-8";

  users.users."cdt" = {
    isNormalUser = true;
    description = "Connor du Toit";
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "kvm"
      "onepassword"
      "onepassword-cli"
    ];
    packages = with pkgs; [];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

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
    polkitPolicyOwners = [ "cdt" ];
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

    # lazyvim runtime deps
    ripgrep
    fd
    gcc
    unzip
    lazygit
    nodejs

    # formatting tools
    nixfmt
    nixd
  ];

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    withUWSM = true;
  };

  xdg.portal.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    nvidiaSettings = true;
    open = false;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    powerManagement.enable = true;
    moduleParams.nvidia.NVreg_TemporaryFilePath = "/var/tmp";
  };

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  networking.firewall.enable = false;
  networking.wireless.iwd.enable = true; # backend for impala
  # networking.networkmanager.enable = true; # backend for nmtui

  stylix = {
    enable = true;
    polarity = "dark";
    image = ./assets/winding-road.jpg;

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
