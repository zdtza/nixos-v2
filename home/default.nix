{
  imports = [
    ./xdg-mimeapps.nix
    ./appearance.nix
    (import ./theme.nix).homeModule
    ./kitty.nix
    ./shell.nix
    ./hyprland.nix
    ./hyprpaper.nix
    ./hypridle.nix
    ./hyprsunset.nix
    ./screen-share.nix
    ./voxtype.nix
    ./btop.nix
    ./nvim.nix
    ./git.nix
    ./web-apps.nix
    ./fzf.nix
    ./yazi.nix
    ./npm.nix
    ./quickshell.nix
  ];
}
