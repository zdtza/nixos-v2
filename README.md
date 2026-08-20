### Setup

1. Install NixOS, set up networking with `nmtui`, then install Git and editor:

```sh
nix-shell -p git neovim
```

2. Clone repo anywhere, enter it, then edit machine-specific graphics settings:

```sh
git clone https://github.com/zdtza/nixos-v2 ~/src/nixos-v2
cd ~/src/nixos-v2
nvim configuration.nix
```

3. Replace generated hardware config:

```sh
rm hardware-configuration.nix
sudo nixos-generate-config
sudo cp /etc/nixos/hardware-configuration.nix ./hardware-configuration.nix
```

4. Rebuild from repo root:

```sh
sudo nixos-rebuild switch --flake .#nixos
```

5. Reboot, then start Hyprland:

```sh
startw
```

Or:

```sh
uwsm start hyprland-uwsm.desktop
```
