{ ... }:

{
  # disko itself (inputs.disko.nixosModules.disko) is imported in
  # modules/hosts/legion.nix. This is just the partition layout.
  flake.nixosModules.disk =
    { ... }:
    {
      disko.devices = {
        disk.main = {
          type = "disk";
          # CHANGE ME: confirm this is the right disk with `lsblk` before
          # running disko - this WILL destroy everything on it.
          device = "/dev/sda";
          content = {
            type = "gpt";
            partitions = {
              ESP = {
                size = "512M";
                type = "EF00";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                  mountOptions = [ "fmask=0077" "dmask=0077" ];
                };
              };

              swap = {
                size = "32G";
                content = {
                  type = "swap";
                };
              };

              # No LUKS - plain btrfs. No "@" subvolume for root: "/" is
              # tmpfs (see hardware.nix), so it's empty every boot with no
              # wipe script needed. @nix and @persist hold everything that
              # must survive a reboot.
              root = {
                size = "100%";
                content = {
                  type = "btrfs";
                  extraArgs = [ "-f" ];
                  subvolumes = {
                    "@nix" = {
                      mountpoint = "/nix";
                      mountOptions = [ "compress=zstd" "noatime" ];
                    };
                    "@persist" = {
                      mountpoint = "/persist";
                      mountOptions = [ "compress=zstd" "noatime" ];
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
}
