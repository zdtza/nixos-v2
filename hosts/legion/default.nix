{ pkgs, ... }:

let
  # This host's one user. Referenced below instead of repeating the
  # literal name everywhere.
  user = "zdtza";

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

    # feature modules this host uses
    ../../modules/core.nix
    ../../modules/desktop.nix
    ../../modules/laptop.nix
    ../../modules/gpu-nvidia.nix
    ../../modules/windows.nix
  ];

  # home-manager modules for this host's user
  home-manager.users.${user}.imports = [
    ../../home/repo.nix
    ../../home/defaults.nix
    ../../home/appearance.nix
    ../../home/kitty.nix
    ../../home/shell.nix
    ../../home/hyprland.nix
    ../../home/hypridle.nix
    ../../home/hyprsunset.nix
    ../../home/screen-share.nix
    ../../home/voxtype.nix
    ../../home/btop.nix
    ../../home/nvim.nix
    ../../home/git.nix
    ../../home/web-apps.nix
    ../../home/fzf.nix
    ../../home/polkit-agent.nix
    ../../home/yazi.nix
    ../../home/npm.nix
    ../../home/quickshell.nix
    ../../home/lazydocker.nix
  ];

  networking.hostName = "legion"; # Lenovo Legion Y540

  # Set your time zone.
  time.timeZone = "Africa/Johannesburg";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_ZA.UTF-8";

  users.users.${user} = {
    isNormalUser = true;
    description = "Connor du Toit";
    shell = pkgs.fish;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "onepassword"
      "onepassword-cli"
      # kvm/docker needed for the windows module, imported above
      "kvm"
      "docker"
    ];
  };

  # PAM policy used by Quickshell's secure Wayland session lock.
  security.pam.services.quickshell = { };

  # trust locally-issued mkcert dev certs (e.g. pmis management-portal) system-wide
  # so Chromium-based webapps (WhatsApp, etc.) and Firefox accept them without warnings.
  # This host's own CA (mkcert generates a distinct one per machine) — regenerate
  # by copying ~/.local/share/mkcert/rootCA.pem here if this host's CA ever rotates.
  security.pki.certificateFiles = [ ./rootCA.pem ];

  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ user ];
  };

  # Windows 11 in a container (dockurr/windows: KVM + QEMU inside Docker).
  windows.user = user;

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
    nix-output-monitor
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
    mpv
    imv
    ripgrep
    fd
    gcc
    unzip
    lazygit
    nodejs
    nixfmt
    nixd
    teams-for-linux
    gnome-disk-utility
    libreoffice
  ];

  networking = {
    firewall = {
      # local send ports
      allowedTCPPorts = [ 53317 ];
      allowedUDPPorts = [ 53317 ];
    };
    # any custom local hosts
    hosts = {
      "127.0.0.1" = localHosts;
      "::1" = localHosts;
    };
  };

  system.stateVersion = "26.05";
}
