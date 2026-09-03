# headless-safe defaults, no gpu/laptop/desktop assumptions live here
{ ... }:
{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  boot = {
    consoleLogLevel = 0;
    initrd.verbose = false;
    kernelParams = [
      "quiet"
      "loglevel=0"
      "udev.log_level=3"
      "systemd.show_status=auto"
    ];
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot = {
        enable = true;
        configurationLimit = 20; # only allow 20 builds to be cached
      };
    };
  };

  nixpkgs.config.allowUnfree = true;

  # registers fish in /etc/shells and sets up system-wide completions
  programs.fish.enable = true;

  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  # lets dynamically linked prebuilt binaries run (nvim-treesitter's
  # tree-sitter-cli, mason.nvim LSP/formatter installs, etc.)
  programs.nix-ld.enable = true;

  networking.networkmanager = {
    enable = true;
    dns = "systemd-resolved";
    # used by custom shell and nmtui to manage Wi-Fi connections
    wifi = {
      backend = "wpa_supplicant";
      powersave = false;
    };
  };

  services.resolved.enable = true;

  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };
}
