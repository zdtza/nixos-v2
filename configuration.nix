{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # /nix and /persist are btrfs and neededForBoot (see below), so the
  # initrd needs btrfs support to mount them.
  boot.initrd.supportedFilesystems = [ "btrfs" ];

  # disko.nix (via ./disko.nix) generates the fileSystems entries; these
  # just layer neededForBoot on top of the /nix and /persist ones it makes.
  fileSystems."/nix".neededForBoot = true;
  fileSystems."/persist".neededForBoot = true;

  networking.hostName = "legion"; # Define your hostname.

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Africa/Johannesburg";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_ZA.UTF-8";

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "za";
    variant = "";
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."cdt" = {
    isNormalUser = true;
    description = "Connor du Toit";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Hyprland (no display manager - launch `Hyprland` from a TTY after login).
  programs.hyprland.enable = true;

  xdg.portal.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];

  hardware.graphics.enable = true;

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # Deploys ~/.config/hypr as a home-manager out-of-store symlink into this
  # flake (~/Nix/hypr) and sets up the config-reload watcher; see ./home.nix.
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users."cdt" = import ./home.nix;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    neovim
    kitty
    eza
    fzf
    zoxide
    yazi
    nautilus
    # hyprland.lua keybindings/settings dependencies
    hyprpicker
    grim
    slurp
    wl-clipboard
    brightnessctl
  ];

  networking.firewall.enable = false;

  system.stateVersion = "26.05"; # Did you read the comment?
}
