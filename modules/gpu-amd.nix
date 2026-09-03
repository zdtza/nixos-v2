# amd gpu, in-tree kernel driver only, nothing proprietary to install
# mutually exclusive with gpu-nvidia.nix, import one or the other
{ ... }:
{
  services.xserver.videoDrivers = [ "amdgpu" ];
}
