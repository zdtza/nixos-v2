# proprietary nvidia driver stack, mutually exclusive with gpu-amd.nix
{ config, pkgs, ... }:
{
  services.xserver.videoDrivers = [ "nvidia" ];

  # loading nvidia kms in initrd, avoids a black screen before greetd grabs the gpu
  boot.initrd.kernelModules = [ "nvidia" ];

  systemd.services = {
  # logind emits PrepareForSleep(false) when the sleep target completes.
  # Finish restoring VRAM/VT before hypridle's display-enable hook runs.
    nvidia-resume = {
    before = [ "suspend.target" "hibernate.target" "suspend-then-hibernate.target" ];
    after = [ "systemd-suspend-then-hibernate.service" ];
    requiredBy = [ "systemd-suspend-then-hibernate.service" ];
  };
    nvidia-suspend = {
      before = [ "systemd-suspend-then-hibernate.service" ];
      requiredBy = [ "systemd-suspend-then-hibernate.service" ];
    };
  };

  # NVIDIA's hook handles the internal suspend -> hibernate transition.
  # Plain suspend/hibernate already use the NixOS NVIDIA services.
  environment.etc."systemd/system-sleep/nvidia".source = pkgs.writeShellScript "nvidia-combined-sleep" ''
    if [ "$2" = suspend-then-hibernate ]; then
      exec ${config.hardware.nvidia.package}/lib/systemd/system-sleep/nvidia "$@"
    fi
  '';

  hardware.nvidia = {
    modesetting.enable = true;
    nvidiaSettings = true;
    open = false;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    powerManagement.enable = true;
    moduleParams.nvidia.NVreg_TemporaryFilePath = "/var/tmp";
  };
}
