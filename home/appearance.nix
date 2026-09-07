{ pkgs, config, lib, ... }:

let
  # Theme selection lives entirely in home-manager (not NixOS), so switching
  # is `sw` (see home/shell.nix's fish function) -- no sudo, no
  # nixos-rebuild. stylix.base16Scheme/image set here as a plain option
  # beats the NixOS module's own values, which stylix forwards down as
  # mkDefault (see stylix's home-manager-integration.nix), so this cleanly
  # wins. `themes` itself is plain data -- see home/theme.nix.
  themes = (import ./theme.nix).themes;
  gtkAccent = themes.${config.theme.name}.gtkAccent;
in
{
  options.theme.name = lib.mkOption {
    type = lib.types.enum (builtins.attrNames themes);
    default = "tokyo-night";
    description = "Selected preset from home/theme.nix's `themes` list.";
  };

  config = {
    stylix = {
      base16Scheme = themes.${config.theme.name}.colors;
      image = themes.${config.theme.name}.wallpaper;
    };

    # `theme-select`/`wallpaper-select` on PATH, no more cd-ing into scripts/ to run them
    home.packages = [
      (pkgs.writeShellScriptBin "theme-select" ''
        exec ${pkgs.bash}/bin/bash ${config.home.homeDirectory}/.src/nixos/scripts/theme-select.sh "$@"
      '')
      (pkgs.writeShellScriptBin "wallpaper-select" ''
        exec ${pkgs.bash}/bin/bash ${config.home.homeDirectory}/.src/nixos/scripts/wallpaper-select.sh "$@"
      '')
    ];

    # GTK has no hot-reload for a custom gtk.css (unlike gtk-theme-name or
    # libadwaita's accent-color above, which do propagate live) -- the CSS
    # provider is only read at startup. Any GTK app you actually launch
    # after `sw` picks up the new colors fine; the only ones that need help
    # are single-instance GApplications that stay resident in the background
    # after their window closes (Nautilus does), since they never relaunch
    # on their own. `nautilus -q` sends an async D-Bus quit instead of
    # killing anything -- the old process can sit tearing down (pending
    # thumbnail/search work) for a long time, and a fast relaunch just
    # reconnects to that still-dying instance instead of starting fresh, so
    # the new theme doesn't show until it *finally* exits. SIGKILL is
    # instant and safe here: a backgrounded file manager holds no unsaved
    # state. nix wraps the real binary as `.nautilus-wrapped`; `comm`
    # truncates to 15 chars (".nautilus-wrapp"), and that's what `pkill -x`
    # matches against, so plain `-x nautilus` silently no-ops (swallowed by
    # `|| true`), leaving the real process alive forever on the old theme.
    # `-f` (cmdline) doesn't work either: argv[0] still shows the wrapper's
    # invoked path (/run/current-system/sw/bin/nautilus), not the real exe.
    # If another resident GNOME app joins the setup, check its comm the
    # same way (`cat /proc/<pid>/comm`) before assuming its plain name works.
    home.activation.nautilusThemeReload = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${pkgs.procps}/bin/pkill -9 -x '.nautilus-wrapp' || true
    '';

    # global color scheme for GTK apps, follows stylix polarity
    gtk.colorScheme = if config.stylix.polarity == "light" then "light" else "dark";

    # global icon theme
    gtk.iconTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };

    # mirrored into dconf too (programs.dconf.enable in modules/wayland.nix):
    # GTK3+/libadwaita apps subscribe to this over D-Bus and re-theme live,
    # settings.ini above only covers apps launched after the fact
    dconf.settings."org/gnome/desktop/interface" = {
      color-scheme = if config.stylix.polarity == "light" then "prefer-light" else "prefer-dark";
      icon-theme = "Adwaita";
      # libadwaita (GTK4) apps -- gnome-calculator, gnome-disks, Nautilus --
      # hold an AdwStyleManager that watches this key and re-renders live.
      accent-color = gtkAccent;
    };

    # stylix's qt target wires up qt6ct/qt5ct but never sets icon_theme in
    # them (no icon_theme key ends up in qt6ct.conf), so QIcon::fromTheme in
    # Qt apps (quickshell included) has no theme to search -- point it at
    # the same theme GTK uses above.
    qt.qt5ctSettings.Appearance.icon_theme = "Adwaita";
    qt.qt6ctSettings.Appearance.icon_theme = "Adwaita";
  };
}
