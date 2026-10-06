{ lib, pkgs, ... }:

let
  # this host's one user, referenced below instead of repeating it everywhere.
  user = "zdtza";
  # Select the system and Home Manager theme in one place.
  themeName = "tokyo-night";

  localHosts = [
    "management-local.pmis.servicesseta.org.za"
    "partner-local.pmis.servicesseta.org.za"
    "learner-local.pmis.servicesseta.org.za"
    "local.scrubbill.net"
  ];

in
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix

    # feature modules this host uses.
    ../../modules/core.nix
    ../../modules/laptop.nix
    ../../modules/windows.nix
  ];

  gpu = "nvidia";

  windows.user = user;

  wayland-desktop = {
    # Quickshell locks the session immediately after autologin.
    autoLoginUser = user;
    themeName = themeName;
  };

  # Home environment and theme.
  home-manager.users.${user} = {
    home.stateVersion = "26.05";
    imports = [ ../../modules/home ];

    theme.name = themeName;

    # making sure that npm lib folder exists for npm link commands.
    home.file.".npm/lib/.keep".text = "";

    programs = {
      # Enable manually to allow Stylix to target it.
      btop.enable = true;
      npm.enable = true;

      # setting up default git credentials for private github.
      git = {
        enable = true;
        settings = {
          user.name = "Connor du Toit";
          user.email = "connordutoit@gmail.com";
          init.defaultBranch = "main";
        };
      };
    };

    # Hide launcher entries for tools that are only opened from other apps.
    xdg.desktopEntries =
      lib.genAttrs
        [
          "uuctl"
          "qt5ct"
          "qt6ct"
          "nvidia-settings"
        ]
        (name: {
          inherit name;
          noDisplay = true;
        });
  };

  # time zone.
  time.timeZone = "Africa/Johannesburg";

  nixpkgs.config.permittedInsecurePackages = [
    "beekeeper-studio-6.1.1"
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

    # local file sharing; also opens its firewall ports.
    localsend.enable = true;

    # Also sets up 32-bit graphics and controller udev rules.
    steam.enable = true;

    # Install Solaar, grant access to Logitech hidraw devices, and start it in the tray.
    solaar = {
      enable = true;
      userService.enable = true;
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
    pi-coding-agent # AI coding assistant
    wiremix # audio mixer
    chromium # web browser
    python3 # programming language
    file # file type identification
    fastfetch # system info tool
    audacity # audio editor
    mkcert # local dev cert
    gnome-calculator # calculator
    mpv # media player
    imv # image viewer
    ripgrep # search tool
    fd # file search tool
    unzip # unzip utility
    p7zip # 7z/rar/etc archives from the terminal (nautilus extracts natively via gnome-autoar)
    lazygit # git UI
    nixfmt # Nix formatter
    nixd # Nix language server
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
    dotnet-sdk_10 # .NET 10 SDK
  ];

  networking = {
    hostName = "legion";

    # Avoid 127.0.0.1: resolved adds ::1 for localhost aliases, causing Node dev servers to bind IPv6-only while Firefox tries IPv4.
    hosts = {
      "127.0.0.3" = localHosts;
    };
  };

  system.stateVersion = "26.05";
}
