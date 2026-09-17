{ pkgs, lib, ... }:

{
  # enabling manually to allow stylix targeting it
  programs.btop.enable = true;

  # SIGUSR2 reloads config and theme in running instances. No process is normal.
  home.activation.btopTheme = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run ${pkgs.procps}/bin/pkill -USR2 -x btop || true
  '';
}
