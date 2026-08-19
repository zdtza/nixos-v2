{ ... }:

{
  flake.nixosModules.hardware =
    { config, lib, modulesPath, ... }:
    {
      imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

      # Root is tmpfs, not a disk partition: it's empty in RAM on every
      # boot by construction (see modules/nixos/impermanence.nix - nothing
      # here needs to survive a reboot unless it's under /persist).
      fileSystems."/" = {
        device = "none";
        fsType = "tmpfs";
        options = [ "defaults" "size=2G" "mode=755" ];
      };

      boot.initrd.availableKernelModules = [
        "xhci_pci"
        "ahci"
        "nvme"
        "usbhid"
        "usb_storage"
        "sd_mod"
      ];
      boot.initrd.kernelModules = [ ];
      boot.kernelModules = [ "kvm-intel" ];
      boot.extraModulePackages = [ ];

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
      hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    };
}
