### Steps for new machine:

1. Install nixos headless onto a new machine via graphical / minimal installer
2. Setup network w/ `nmtui` and grab `git`, and prefferred text editor:

```
nix-shell -p git neovim
```
3. Clone this repo into the home directory under `~/nixos`

```
git clone https://github.com/zdtza/nixos-v2 ~/nixos
```
4. Make sure that the graphics are configured for your machine in `nvim ~/nixos/configuration.nix` in graphics section
5. Remove the default hardware-configuration.nix file at `rm ~/nixos/hardware-configuration.nix`
6. Generate the current hardware config:

```
sudo nixos-generate-config
```
7. Copy the output to a new hardware-configuration.nix to `~/nixos`:

```
sudo cp /etc/nixos/hardware-configuration.nix ~/nixos/hardware-configuration.nix
```
8. Rebuild and switch:
   
```
sudo nixos-rebuild switch --flake ~/nixos#nixos
```
9. Reboot and login
10. Start the hyprland session with uwsm via:

```
startw
```

OR

```
uwsm start hyprland-uwsm.desktop
```