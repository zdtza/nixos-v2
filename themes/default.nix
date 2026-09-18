# Every theme lives in its own folder next to this file.
let
  entries = builtins.readDir ./.;
  names = builtins.filter (name: entries.${name} == "directory") (builtins.attrNames entries);
in
{
  themes = builtins.listToAttrs (map (name: {
    inherit name;
    value = import (./. + "/${name}");
  }) names);
}
