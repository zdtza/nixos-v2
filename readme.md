## Rules for this configuration!
1. No inline scripts
2. Simple AF!

## Install
1. Confirm disk in `modules/nixos/disk.nix` matches `lsblk -f`.
2. Boot NixOS installer, get this repo onto it.
3. `sudo ./install.sh`
4. Reboot, remove media, log in as `cdt` (password `changeme`, then run `passwd`), run `Hyprland`.