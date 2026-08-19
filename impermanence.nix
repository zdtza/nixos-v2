{
  # Root is tmpfs (see hardware-configuration.nix), so it's already empty
  # on every boot - no wipe script needed. Anything not listed here is
  # gone on reboot. /nix and /persist live on real, persistent btrfs
  # subvolumes (see disko.nix).
  environment.persistence."/persist" = {
    hideMounts = true;

    files = [
      "/etc/machine-id"
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
    ];
  };
}
