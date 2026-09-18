{ lib, ... }:

{
  xdg.desktopEntries = lib.genAttrs [
    "uuctl"
    "qt5ct"
    "qt6ct"
    "nvidia-settings"
  ] (name: {
    inherit name;
    noDisplay = true;
  });
}
