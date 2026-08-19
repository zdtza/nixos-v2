## Rules for this configuration!
1. No inline scripts
2. Simple AF!

## Install
1. Confirm disk in `modules/nixos/disk.nix` matches `lsblk -f`.
2. Boot NixOS installer, get this repo onto it.
3. `sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko --flake /path/to/repo#legion`
4. `mkdir -p /mnt/persist/home/cdt && cp -r /path/to/repo /mnt/persist/home/cdt/Nix`
5. `sudo nixos-install --flake /mnt/persist/home/cdt/Nix#legion --root /mnt`
6. `sudo nixos-enter --root /mnt -c 'passwd cdt'`
7. Reboot, remove media, log in as `cdt`, run `Hyprland`.