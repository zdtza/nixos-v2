# AMD GPU. Deliberately thin: amdgpu is the in-tree/default kernel driver
# and mesa (via hardware.graphics.enable in modules/desktop.nix) covers
# Vulkan/OpenGL — nothing proprietary to install. Mutually exclusive with
# gpu-nvidia.nix on a given host — import one or the other, not both.
{ ... }:
{
  services.xserver.videoDrivers = [ "amdgpu" ];
}
