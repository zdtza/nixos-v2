{ ... }:

{
  # The environment.persistence option itself comes from
  # inputs.impermanence.nixosModules.impermanence, imported in
  # modules/hosts/legion.nix. This is just the config for it.
  flake.nixosModules.impermanence =
    { ... }:
    {
      fileSystems."/nix".neededForBoot = true;
      fileSystems."/persist".neededForBoot = true;

      # Root is tmpfs (see hardware.nix), so it's already empty on every
      # boot - no wipe script needed. Anything not listed here is gone on
      # reboot. /nix and /persist live on real, persistent btrfs
      # subvolumes (see disk.nix).
      environment.persistence."/persist" = {
        hideMounts = true;

        files = [
          "/etc/machine-id"
          "/home/cdt/.claude.json"
        ];

        directories = [
          "/var/lib/nixos"
          "/var/log"
          "/var/lib/bluetooth"
          "/etc/NetworkManager"
          "/home/cdt/Nix"
          "/home/cdt/Downloads"
          "/home/cdt/Documents"
          "/home/cdt/Dev"
          "/home/cdt/.claude"
        ];
      };
    };
}
