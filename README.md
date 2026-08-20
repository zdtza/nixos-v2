### Steps for new machine:

1. Install nixos headless onto a new machine via graphical / minimal installer
2. Setup network w/ `nmtui` and grab `git`, and prefferred text editor:

```
nix-shell -p git neovim
```
1. Clone this repo into the home directory under ~/nixos
2. Remove the default hardware-configuration.nix file
3. Make sure that the graphics are configured for your machine in ~/nixos/configuration.nix
4. Generate the config:

```
sudo nixos-generate-config
```
5. Copy the output to a new hardware-configuration.nix to ~/nixos:

```
sudo cp /etc/nixos/hardware-configuration.nix ~/nixos/hardware-configuration.nix
```
6. Rebuild and switch:
   
```
sudo nixos-rebuild switch --flake ~/nixos#nixos
```
7. Reboot and login via tty
8. Start the hyprland session with uwsm via:

```
startw
```