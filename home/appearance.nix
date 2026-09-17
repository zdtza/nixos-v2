{
  pkgs,
  config,
  lib,
  ...
}:

let
  # Home-manager selection overrides the NixOS Stylix fallback.
  themes = (import ../themes).themes;
  theme = themes.${config.theme.name};

  # Static: one Yaru variant for every theme.
  iconTheme = "Yaru-dark";

  # Nautilus folders match yazi's Nerd Font glyphs; other icons inherit Yaru.
  folderThemeName = "yazi-folders";

  folderIcons =
    let
      accent = config.lib.stylix.colors.withHashtag.${theme.accent};
      font = config.stylix.fonts.monospace.name;
      # Measured offsets center the glyph ink, not its advance width.
      # Recheck with `rsvg-convert | magick -format %@` after font changes.
      svg = cp: ''
        <svg xmlns="http://www.w3.org/2000/svg" width="128" height="128">
          <text x="49" y="110" text-anchor="middle" fill="${accent}"
                font-family="${font}" font-size="128">&#x${cp};</text>
        </svg>'';
      # Special directories use the same folder glyph as ordinary directories.
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
      ${lib.concatMapStringsSep "\n" (n: "ln -s folder.svg $d/${n}.svg") (lib.tail names)}
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
      base16Scheme = theme.colors;
      image = theme.wallpaper;
      polarity = theme.polarity;

      # Match GtkSourceView's document area to the surrounding GTK palette.
      targets.gtk.extraCss = ''
        textview.sourceview,
        textview.sourceview text {
          background-color: @view_bg_color;
          color: @view_fg_color;
        }
      '';
    };

    # Relink on home activation instead of requiring a system-profile rebuild.
    # GTK searches XDG_DATA_HOME/icons directly.
    xdg.dataFile."icons/${folderThemeName}".source = folderIcons;

    # Expose the theme and wallpaper selectors on PATH.
    home.packages = [
      (pkgs.writeShellScriptBin "select-theme" ''
        exec ${pkgs.bash}/bin/bash ${config.home.homeDirectory}/.src/nixos/scripts/select-theme.sh "$@"
      '')
      (pkgs.writeShellScriptBin "select-wallpaper" ''
        exec ${pkgs.bash}/bin/bash ${config.home.homeDirectory}/.src/nixos/scripts/select-wallpaper.sh "$@"
      '')
    ];

    # Stylix owns color-scheme via polarity. GTK CSS changes require app restart.
    gtk.iconTheme = {
      name = folderThemeName;
      package = pkgs.yaru-theme;
    };

    dconf.settings = {
      # Notify running GTK apps of icon-theme changes over D-Bus.
      "org/gnome/desktop/interface".icon-theme = folderThemeName;

      # Heavier weight matches kitty's rendering of the same font.
      "org/gnome/TextEditor" = {
        use-system-font = false;
        custom-font = "${config.stylix.fonts.monospace.name} SemiBold 11.5";
      };
    };

    # Stylix configures qt5ct/qt6ct but leaves their icon theme unset.
    qt = {
      qt5ctSettings.Appearance.icon_theme = iconTheme;
      qt6ctSettings.Appearance.icon_theme = iconTheme;
    };
  };
}
