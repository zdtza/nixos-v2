{ pkgs, config, lib, ... }:

let
  # Links nothing but libc on purpose -- glib is here for headers only, and the
  # installCheck below fails the build if a stray -l ever sneaks in, since a
  # session-wide LD_PRELOAD that drags gtk4 into every process is a different
  # (and much worse) thing than the no-op mmap this is meant to be.
  gtk-live-css = pkgs.stdenv.mkDerivation {
    pname = "gtk-live-css";
    version = "1";

    src = ./gtk-live-css.c;
    dontUnpack = true;

    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [ pkgs.glib ];

    buildPhase = ''
      $CC -O2 -Wall -Wextra -fPIC -shared -o libgtk-live-css.so "$src" \
        $(pkg-config --cflags glib-2.0 gio-2.0)
    '';

    installPhase = ''
      install -Dm755 libgtk-live-css.so $out/lib/libgtk-live-css.so
    '';

    doInstallCheck = true;
    installCheckPhase = ''
      # The two interposed entry points must actually be exported, or the
      # preload silently does nothing in every app.
      for sym in g_application_run gtk_main; do
        nm -D --defined-only $out/lib/libgtk-live-css.so | grep -qw "$sym" ||
          { echo "missing hook: $sym"; exit 1; }
      done

      # Nothing but libc/libdl may be pulled in.
      if ldd $out/lib/libgtk-live-css.so | grep -qE 'lib(gtk|glib|gobject|gio)'; then
        echo "linked against GTK/GLib; it must resolve those at runtime instead"
        exit 1
      fi
    '';
  };
in
{
  # Session-wide rather than per-app: Nautilus and friends are D-Bus activated
  # by the systemd user manager, so wrapping desktop entries would miss exactly
  # the resident apps this exists for. environment.d is read by that manager, so
  # both activated services and anything Hyprland spawns inherit it.
  # Takes effect at next login (the user manager reads environment.d once).
  xdg.configFile."environment.d/50-gtk-live-css.conf".text = ''
    LD_PRELOAD=${gtk-live-css}/lib/libgtk-live-css.so
  '';

  # The file the preload watches. It cannot be the stylix-generated config
  # itself: those are symlinks into the store that home-manager replaces
  # wholesale, and a GFileMonitor on a swapped symlink is not something to bet
  # a theme switch on. Copy the same content to a stable path instead, then
  # rename it into place so each switch is one atomic event, not a truncate
  # the app can catch mid-write.
  # A GTK process can only retint if it has *this* build of the shim mapped.
  # Two ways it can end up without one: it was started before the LD_PRELOAD in
  # environment.d reached the session (first login after adding this), or the
  # shim was rebuilt and its store path moved. Such a process is not visibly
  # broken -- it just quietly stops following theme switches, which is a
  # miserable thing to debug twice. Resident single-instance GApplications are
  # the only ones that matter (they outlive their last window and never
  # relaunch on their own), and a backgrounded file manager holds no unsaved
  # state, so killing it is safe. `comm` truncates to 15 chars and nix wraps
  # the binary, hence `.nautilus-wrapp`: `pgrep -x nautilus` matches nothing,
  # and `-f` fails too, since argv[0] is the wrapper's path.
  home.activation.gtkLiveCssRestart = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    for pid in $(${pkgs.procps}/bin/pgrep -x .nautilus-wrapp || true); do
      grep -q '${gtk-live-css}/lib/libgtk-live-css.so' "/proc/$pid/maps" 2>/dev/null ||
        run ${pkgs.procps}/bin/kill -9 "$pid"
    done
  '';

  home.activation.gtkLiveCss = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    for v in 3 4; do
      src="${config.xdg.configHome}/gtk-$v.0/gtk.css"
      dst="${config.xdg.cacheHome}/gtk-live-$v.css"
      [ -e "$src" ] || continue
      run install -Dm644 "$src" "$dst.new"
      run mv -f "$dst.new" "$dst"
    done
  '';
}
