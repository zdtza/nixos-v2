# AMD GPU using the in-tree driver; conflicts with gpu-nvidia.nix.
{ ... }:
{
  services.xserver.videoDrivers = [ "amdgpu" ];
}
