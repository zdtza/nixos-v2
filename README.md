### Layout

- `hosts/<name>/` — one directory per machine: `default.nix` (host-specific
  config, which `../../modules/*.nix` it imports, and that host's
  `home-manager.users.<user>.imports` list), `hardware-configuration.nix`
  (generated, machine-specific).
- `modules/` — reusable pieces (`core`, `desktop`, `laptop`, `gpu-nvidia`,
  `gpu-amd`, `windows`). Plain config, no flags — a host uses one by adding
  it to its own `imports`, nothing more.
- `home/` — home-manager modules, picked per-host via each host's
  `home-manager.users.<user>.imports` in `default.nix`.

### Adding a new host

1. `mkdir hosts/<name>`, generate hardware config into it:

```sh
sudo nixos-generate-config --dir hosts/<name>
rm hosts/<name>/configuration.nix   # not used, hosts/<name>/default.nix replaces it
```

2. Write `hosts/<name>/default.nix`. Minimum: `networking.hostName`,
   `system.stateVersion`, and an `imports` list with
   `./hardware-configuration.nix` plus whichever `../../modules/*.nix` this
   host needs, e.g.:

```nix
imports = [
  ./hardware-configuration.nix
  ../../modules/core.nix       # any headless-safe host
  ../../modules/desktop.nix    # Hyprland desktop
  ../../modules/laptop.nix     # TLP, bluetooth, suspend tuning
  ../../modules/gpu-nvidia.nix # or gpu-amd.nix
  ../../modules/windows.nix    # dockurr/windows VM, needs windows.user set below
];

windows.user = "you";
```

3. In the same file, set `home-manager.users.<user>.imports` to a list of
   `../../home/*.nix` paths for that host's user. A headless host needs far
   fewer than a desktop.

4. Add `"<name>"` to `hostNames` in `flake.nix`.

5. `nix flake check` and `nix build .#nixosConfigurations.<name>.config.system.build.toplevel --no-link`
   before switching on real hardware.

### First-time setup on new hardware

1. Install NixOS, set up networking with `nmtui`, then install Git and editor:

```sh
nix-shell -p git neovim
```

2. Clone repo anywhere:

```sh
git clone https://github.com/zdtza/nixos-v2 ~/src/nixos-v2
cd ~/src/nixos-v2
```

3. Add the host per "Adding a new host" above (or reuse an existing
   `hosts/<name>/` if reinstalling the same machine — just regenerate
   `hardware-configuration.nix`).

4. Rebuild from repo root:

```sh
sudo nixos-rebuild switch --flake .#<name>
```

5. Reboot, then start Hyprland (desktop hosts only):

```sh
startw
```

Or:

```sh
uwsm start hyprland-uwsm.desktop
```
