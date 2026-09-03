{ pkgs, ... }:

let
  # this host's one user, referenced below instead of repeating it everywhere
  user = "zdtza";

  localHosts = [
    "management-local.pmis.servicesseta.org.za"
    "partner-local.pmis.servicesseta.org.za"
    "learner-local.pmis.servicesseta.org.za"
  ];
in
{
  # windows 11 in a container (dockurr/windows: kvm + qemu inside docker)
  windows.user = user;

  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix

    # feature modules this host uses
    ../../modules/base.nix
    ../../modules/wayland.nix
    ../../modules/laptop.nix
    ../../modules/gpu-nvidia.nix
    ../../modules/windows.nix
  ];

  # home-manager modules for this host's user
  home-manager.users.${user} = {
    home.stateVersion = "26.05";
    imports = [ ../../home ];
  };

  networking.hostName = "legion"; # lenovo legion y540

  # time zone
  time.timeZone = "Africa/Johannesburg";

  # locale
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
      "docker"
    ];
  };

  # pam policy for quickshell's secure wayland session lock
  security.pam.services.quickshell = { };

  # trusting local mkcert dev certs system-wide, so chromium webapps and firefox
  # accept them; regenerate from ~/.local/share/mkcert/rootCA.pem if this host's CA rotates
  security.pki.certificateFiles = [ ./rootCA.pem ];

  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ user ];
  };

 
  environment.systemPackages = with pkgs; [
    nautilus # file manager
    firefox # web browser
    fzf # fuzzy finder
    eza # better ls
    yazi # file manager
    slurp # screenshot selection tool
    brightnessctl # adjust screen brightness
    vscode # code editor
    git # version control
    grim # screenshot tool
    claude-code # AI code assistant
    wl-clipboard # clipboard manager
    hyprpicker # color picker
    hyprpaper # wallpaper manager
    bluetui # bluetooth manager
    localsend # local file sharing
    pi-coding-agent # AI coding assistant
    wiremix # audio mixer
    btop # system monitor
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
    libnotify # desktop notifications
    mpv # media player
    imv # image viewer
    ripgrep # search tool
    fd # file search tool
    gcc # C/C++ compiler
    unzip # unzip utility
    lazygit # git UI
    nodejs # JavaScript runtime
    nixfmt # Nix formatter
    nixd # Nix daemon
    teams-for-linux # Microsoft Teams client
    gnome-disk-utility # disk management
    libreoffice # office suite
    gh # GitHub CLI
    gdu # disk usage analyzer
    lazydocker # Docker UI
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
