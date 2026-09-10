{ pkgs, lib, ... }:

{
  # enabling manually to allow stylix targeting it
  programs.btop.enable = true;

  # btop loads its theme once at startup, so a theme switch has to be pushed
  # into instances that are already open -- same story as yazi/nvim. SIGUSR2 is
  # btop's own hot-reload path (identical to CTRL+R): re-reads btop.conf, then
  # updateThemes() + setTheme(), which re-reads themes/stylix.theme from a
  # stable path whose symlink target this activation just swapped -- so no
  # in-place rewrite is needed and nothing has to be killed.
  # -x matches the comm, which is plain "btop" here (real ELF, no nix wrapper);
  # pkill exits 1 when nothing is running, the normal case, so swallow it.
  home.activation.btopTheme = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run ${pkgs.procps}/bin/pkill -USR2 -x btop || true
  '';
}
