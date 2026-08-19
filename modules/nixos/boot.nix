{ ... }:

{
  flake.nixosModules.boot =
    { pkgs, ... }:
    {
      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;
      boot.kernelPackages = pkgs.linuxPackages_latest;

      # /nix and /persist are btrfs and neededForBoot (see impermanence.nix),
      # so the initrd needs btrfs support to mount them.
      boot.initrd.supportedFilesystems = [ "btrfs" ];
    };
}
