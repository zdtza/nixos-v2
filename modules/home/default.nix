{ config, lib, ... }:
{
  # Checkout path for files symlinked out of the store so they stay directly editable.
  options.repoPath = lib.mkOption {
    type = lib.types.str;
    default = "${config.home.homeDirectory}/.src/nixos";
    description = "Location of this flake's checkout.";
  };

  imports = [
    ./xdg-mimeapps.nix
    ./appearance.nix
    ./kitty.nix
    ./shell.nix
    ./hyprland.nix
    ./hypridle.nix
    ./screen-share.nix
    ./screenshot.nix
    ./voxtype.nix
    ./nvim.nix
    ./ssh.nix
    ./web-apps.nix
    ./fzf.nix
    ./yazi.nix
    ./quickshell.nix
    ./services.nix
  ];
}
