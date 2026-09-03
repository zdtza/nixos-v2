# proprietary nvidia driver stack, mutually exclusive with gpu-amd.nix
{ config, ... }:
{
  services.xserver.videoDrivers = [ "nvidia" ];

  # loading nvidia kms in initrd, avoids a black screen before greetd grabs the gpu
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
