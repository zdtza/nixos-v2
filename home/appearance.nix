{ pkgs, config, lib, ... }:

let
  # Theme selection lives entirely in home-manager (not NixOS), so switching
  # is `sw` (see home/shell.nix's fish function) -- no sudo, no
  # nixos-rebuild. stylix.base16Scheme/image set here as a plain option
  # beats the NixOS module's own values, which stylix forwards down as
  # mkDefault (see stylix's home-manager-integration.nix), so this cleanly
  # wins. `themes` itself is plain data -- see themes/default.nix.
  themes = (import ../themes).themes;

  # Static: one Yaru variant for every theme.
  iconTheme = "Yaru-dark";

  # Nautilus resolves icons by *name* out of a GTK icon theme, it cannot read
  # a font glyph -- so hand it a theme whose folder.svg IS the yazi glyph
  # (home/yazi.nix's dir rule, nf-md-folder U+F024B / open U+F0770) drawn as
  # SVG <text>; librsvg renders that through pango, same fontconfig face and
  # same accent color yazi uses. Inherits Yaru, so every non-folder icon still
  # comes from there.
  folderThemeName = "yazi-folders";

  folderIcons =
    let
      accent = config.lib.stylix.colors.withHashtag.${themes.${config.theme.name}.accent};
      font = config.stylix.fonts.monospace.name;
      # The glyph's ink is not centered in its advance width, so text-anchor
      # alone puts it off to the right and clips it -- x/y/size are measured
      # tuning knobs, not geometry that can be derived. At these values the
      # two glyphs land at 108x86 and 114x86 ink inside the 128 box (10px side
      # margins, vertically centered), which reads at the same weight as the
      # glyph in a yazi cell. Re-measure with
      # `rsvg-convert | magick -format %@` after changing the face or size:
      # x/y are ink_margin + the glyph's own offset from its anchor, so both
      # move when font-size does.
      svg = cp: ''
        <svg xmlns="http://www.w3.org/2000/svg" width="128" height="128">
          <text x="49" y="110" text-anchor="middle" fill="${accent}"
                font-family="${font}" font-size="128">&#x${cp};</text>
        </svg>'';
      # yazi shows one glyph for every directory, so all of Nautilus's folder
      # names (special dirs included) point at the same file.
      names = [
        "folder"
        "inode-directory"
        "folder-documents"
        "folder-download"
        "folder-music"
        "folder-pictures"
        "folder-videos"
        "folder-publicshare"
        "folder-templates"
        "folder-desktop"
        "folder-remote"
        "user-home"
        "user-desktop"
        "user-bookmarks"
      ];
    in
    pkgs.runCommand folderThemeName { } ''
      d=$out/scalable/places
      mkdir -p $d
      cat > $out/index.theme <<'EOF'
      [Icon Theme]
      Name=${folderThemeName}
      Comment=yazi folder glyphs over ${iconTheme}
      Inherits=${iconTheme},Adwaita,hicolor
      Directories=scalable/places

      [scalable/places]
      Size=128
      MinSize=8
      MaxSize=512
      Context=Places
      Type=Scalable
      EOF
      cat > $d/folder.svg <<'EOF'
      ${svg "F024B"}
      EOF
      cat > $d/folder-open.svg <<'EOF'
      ${svg "F0770"}
      EOF
      ln -s folder-open.svg $d/folder-drag-accept.svg
      ln -s folder-open.svg $d/folder-visiting.svg
      ${lib.concatMapStringsSep "\n" (n: "ln -s folder.svg $d/${n}.svg") (
        lib.tail names
      )}
    '';
in
{
  options.theme.name = lib.mkOption {
    type = lib.types.enum (builtins.attrNames themes);
    default = "tokyo-night";
    description = "Selected preset from the themes/ folder (one subfolder per theme).";
  };

  config = {
    stylix = {
      base16Scheme = themes.${config.theme.name}.colors;
      image = themes.${config.theme.name}.wallpaper;
      # Light themes exist in themes/ (catppuccin-latte, white, ...), and every
      # target stylix generates keys off polarity, so it follows theme.name too
      # -- modules/wayland.nix only sets the pre-login fallback.
      polarity = themes.${config.theme.name}.polarity;

      # GtkSourceView apps (gnome-text-editor, Builder) paint the document area
      # from stylix's style scheme, not from GTK colors; repaint it from the
      # GTK palette so it matches the rest of the window.
      targets.gtk.extraCss = ''
        textview.sourceview,
        textview.sourceview text {
          background-color: @view_bg_color;
          color: @view_fg_color;
        }
      '';
    };

    # Shipped as a file, not a package: home.packages land in
    # /etc/profiles/per-user (useUserPackages), which only a nixos-rebuild
    # rewrites, while xdg.dataFile is relinked by every home activation. GTK
    # searches XDG_DATA_HOME/icons regardless of XDG_DATA_DIRS.
    xdg.dataFile."icons/${folderThemeName}".source = folderIcons;

    # `select-theme`/`select-wallpaper` on PATH, no more cd-ing into scripts/ to run them
    home.packages = [
      (pkgs.writeShellScriptBin "select-theme" ''
        exec ${pkgs.bash}/bin/bash ${config.home.homeDirectory}/.src/nixos/scripts/select-theme.sh "$@"
      '')
      (pkgs.writeShellScriptBin "select-wallpaper" ''
        exec ${pkgs.bash}/bin/bash ${config.home.homeDirectory}/.src/nixos/scripts/select-wallpaper.sh "$@"
      '')
    ];

    # GTK loads gtk.css once at startup, so running GTK apps keep the old theme
    # until restarted. Resident single-instance apps never relaunch on their
    # own: `pkill -9 -x '.nautilus-wrapp'` (the comm -- nix wraps the binary and
    # comm truncates to 15 chars, so `pkill -x nautilus` matches nothing).

    # gtk.colorScheme is stylix's job: it sets it (and the matching
    # org/gnome/desktop/interface color-scheme) from polarity, and setting
    # either here conflicts with stylix's own value on light themes.

    gtk.iconTheme = {
      name = folderThemeName;
      package = pkgs.yaru-theme;
    };


    # mirrored into dconf too (programs.dconf.enable in modules/wayland.nix):
    # GTK3+/libadwaita apps subscribe to this over D-Bus and re-theme live,
    # settings.ini above only covers apps launched after the fact.
    # color-scheme is stylix's (modules/gnome/hm.nix), which sets it from
    # polarity -- setting it here too conflicts on light themes.
    dconf.settings."org/gnome/desktop/interface".icon-theme = folderThemeName;

    # GNOME Text Editor otherwise inherits monospace-font-name (Regular), which
    # renders lighter than kitty's rasterization of the same face. Medium matches
    # it; swap weight/size in the string below to taste.
    dconf.settings."org/gnome/TextEditor" = {
      use-system-font = false;
      custom-font = "${config.stylix.fonts.monospace.name} SemiBold 11.5";
    };

    # stylix's qt target wires up qt6ct/qt5ct but never sets icon_theme in
    # them (no icon_theme key ends up in qt6ct.conf), so QIcon::fromTheme in
    # Qt apps (quickshell included) has no theme to search -- point it at Yaru.
    qt.qt5ctSettings.Appearance.icon_theme = iconTheme;
    qt.qt6ctSettings.Appearance.icon_theme = iconTheme;
  };
}
