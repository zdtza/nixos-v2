# Headless defaults shared by all hosts.
{ pkgs, ... }:
{
  boot = {
    consoleLogLevel = 0;
    initrd.verbose = false;
    kernelParams = [
      "quiet"
      "loglevel=0"
      "udev.log_level=3"
      "systemd.show_status=true"
    ];
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot = {
        enable = true;
        configurationLimit = 20;
      };
    };
  };

  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };
  nixpkgs.config.allowUnfree = true;

  programs = {
    fish.enable = true;
    neovim = {
      enable = true;
      defaultEditor = true;
    };
    # Run prebuilt binaries, including editor-installed language servers.
    nix-ld = {
      enable = true;
      # The Microsoft SQL Server extension's bundled .NET services load ICU
      # dynamically and abort at startup when it is absent.
      libraries = [ pkgs.icu ];
    };
  };

  networking.networkmanager = {
    enable = true;
    dns = "systemd-resolved";
    wifi = {
      backend = "wpa_supplicant";
      powersave = false;
    };
  };

  services = {
    resolved.enable = true;
    samba-wsdd = {
      enable = true;
      openFirewall = true;
    };
  };
}
