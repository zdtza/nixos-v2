# Proprietary NVIDIA driver stack. Mutually exclusive with gpu-amd.nix on a
# given host — import one or the other, not both.
{ config, ... }:
{
  services.xserver.videoDrivers = [ "nvidia" ];

  # Load nvidia KMS in initrd so the console (and greetd/tuigreet) has a
  # mode-set display ready before userspace starts, instead of a black
  # screen until Xorg/Wayland later grabs the GPU.
  boot.initrd.kernelModules = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    nvidiaSettings = true;
    open = false;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    powerManagement.enable = true;
    moduleParams.nvidia.NVreg_TemporaryFilePath = "/var/tmp";
  };
}
