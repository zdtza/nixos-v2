{ ... }:

{
  # stylix itself (inputs.stylix.nixosModules.stylix) is imported in
  # modules/hosts/legion.nix. This is just the theme config. Since
  # home-manager is imported as a NixOS module there too, this single
  # system-level config also themes the home-manager side (Hyprland's
  # hyprpaper wallpaper included) - no separate home-manager config needed.
  flake.nixosModules.theme =
    { pkgs, ... }:
    {
      # Tokyo Night colors ported from ~/NixOS/themes/tokyo-night/colors.toml.
      stylix = {
        enable = true;
        polarity = "dark";
        image = ../../theme/wallpaper.jpg;

        base16Scheme = {
          base00 = "#1a1b26"; # background
          base01 = "#13141c"; # dark_background
          base02 = "#292e42"; # selection
          base03 = "#414868"; # muted
          base04 = "#565f89"; # dark_foreground
          base05 = "#a9b1d6"; # foreground
          base06 = "#b4bee6"; # light_foreground
          base07 = "#c0caf5"; # bright_foreground
          base08 = "#f7768e"; # red
          base09 = "#eb927b"; # orange
          base0A = "#e0af68"; # yellow
          base0B = "#9ece6a"; # green
          base0C = "#449dab"; # cyan
          base0D = "#7aa2f7"; # blue
          base0E = "#ad8ee6"; # magenta
          base0F = "#75493d"; # brown
        };

        # hyprpaper's "wallpaper = ,<path>" with an empty monitor name
        # applies to every connected monitor - what this target emits.
        targets.hyprpaper.enable = true;

        fonts = {
          serif = {
            package = pkgs.dejavu_fonts;
            name = "DejaVu Serif";
          };

          sansSerif = {
            package = pkgs.dejavu_fonts;
            name = "DejaVu Sans";
          };

          monospace = {
            package = pkgs.nerd-fonts.jetbrains-mono;
            name = "JetBrainsMono Nerd Font";
          };

          emoji = {
            package = pkgs.noto-fonts-color-emoji;
            name = "Noto Color Emoji";
          };
        };
      };
    };
}
