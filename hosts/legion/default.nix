{ pkgs, ... }:

let
  # this host's one user, referenced below instead of repeating it everywhere.
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

    # feature modules this host uses.
    ../../modules/base.nix
    ../../modules/wayland.nix
    ../../modules/laptop.nix
    ../../modules/gpu-nvidia.nix
    ../../modules/postgresql.nix
    ../../modules/windows.nix
  ];

  windows.user = user;

  # Quickshell locks the session immediately after autologin.
  wayland-desktop.autoLoginUser = user;

  # Home environment and theme.
  home-manager.users.${user} = {
    home.stateVersion = "26.05";
    imports = [ ../../home ];

    # Select from themes/; apply user-only changes with `sw`.
    theme.name = "tokyo-night";
  };

  # time zone.
  time.timeZone = "Africa/Johannesburg";

  nixpkgs.config.permittedInsecurePackages = [
    "beekeeper-studio-6.0.5"
  ];

  # locale.
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
      "kvm"
    ];
  };

  programs = {
    _1password.enable = true;
    _1password-gui = {
      enable = true;
      polkitPolicyOwners = [ user ];
    };
  };

  security = {
    # Unlock the login keyring with the Quickshell session password.
    pam.services.quickshell.enableGnomeKeyring = true;

    # Local mkcert CA; refresh this file if the host's CA rotates.
    pki.certificateFiles = [ ./rootCA.pem ];
  };

  environment.systemPackages = with pkgs; [
    nautilus # file manager
    firefox # web browser
    eza # better ls
    brightnessctl # adjust screen brightness
    vscode # code editor
    claude-code # AI code assistant
    wl-clipboard # clipboard manager
    hyprpicker # color picker
    bluetui # bluetooth manager
    localsend # local file sharing
    pi-coding-agent # AI coding assistant
    wiremix # audio mixer
    chromium # web browser
    python3 # programming language
    file # file type identification
    font-awesome # icon fonts
    fastfetch # system info tool
    audacity # audio editor
    dotnet-sdk_10 # .NET SDK
    mkcert # local dev certs
    steam # gaming platform
    gnome-calculator # calculator
    mpv # media player
    imv # image viewer
    ripgrep # search tool
    fd # file search tool
    unzip # unzip utility
    p7zip # 7z/rar/etc archives from the terminal (nautilus extracts natively via gnome-autoar)
    lazygit # git UI
    nixfmt # Nix formatter
    nixd # Nix daemon
    teams-for-linux # Microsoft Teams client
    gnome-disk-utility # disk management
    libreoffice # office suite
    gh # GitHub CLI
    gdu # disk usage analyzer
    lazydocker # Docker UI
    obsidian # note-taking app
    blender # 3D modeling software
    gnome-text-editor # basic text editor
    papers # document viewer / editor
    beekeeper-studio # data-base management tool
    bruno # api management tool
  ];

  networking = {
    hostName = "legion";

    firewall = {
      # local send ports.
      allowedTCPPorts = [ 53317 ];
      allowedUDPPorts = [ 53317 ];
    };
    # Avoid 127.0.0.1: resolved adds ::1 for localhost aliases, causing Node dev servers to bind IPv6-only while Firefox tries IPv4.
    hosts = {
      "127.0.0.3" = localHosts;
    };
  };

  system.stateVersion = "26.05";
}
