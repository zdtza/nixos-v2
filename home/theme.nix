# Theme selection lives entirely in home-manager (not NixOS), so switching
# is `sw` (see home/shell.nix's fish function) -- no sudo, no nixos-rebuild.
# stylix.base16Scheme/image set here as a plain option beat the NixOS
# module's own values, which stylix forwards down as mkDefault (see
# stylix's home-manager-integration.nix), so this cleanly wins.
#
# `themes` is plain data (no lib/config args), so it can be `import`-ed
# standalone by scripts/theme-select.sh, home/nvim.nix and
# modules/wayland.nix (a NixOS module, outside home-manager's module tree).
# `homeModule` is the actual home-manager module, wired up in
# home/default.nix as `(import ./theme.nix).homeModule`.
let
  themes = {
    tokyo-night = {
      wallpaper = ../assets/wallpapers/tokyo-night/0-winding-road.jpg;
      colors = {
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
        base0C = "#4dbfd0"; # cyan
        base0D = "#7aa2f7"; # blue
        base0E = "#ad8ee6"; # magenta
        base0F = "#75493d"; # brown
      };
      # neovim mapping style borrowed from ~/omarchy/themes/*/neovim.lua
      neovim = {
        plugin = "https://github.com/folke/tokyonight.nvim";
        colorscheme = "tokyonight-night";
        lualine = "tokyonight";
      };
    };

    catppuccin-mocha = {
      wallpaper = ../assets/wallpapers/catppuccin-mocha/2-waves.jpg;
      colors = {
        base00 = "#1e1e2e";
        base01 = "#181825";
        base02 = "#313244";
        base03 = "#45475a";
        base04 = "#585b70";
        base05 = "#cdd6f4";
        base06 = "#f5e0dc";
        base07 = "#b4befe";
        base08 = "#f38ba8";
        base09 = "#fab387";
        base0A = "#f9e2af";
        base0B = "#a6e3a1";
        base0C = "#94e2d5";
        base0D = "#89b4fa";
        base0E = "#cba6f7";
        base0F = "#f2cdcd";
      };
      neovim = {
        plugin = "https://github.com/catppuccin/nvim";
        # catppuccin.nvim's own colorscheme is flavour-less; flavour is set in setup()
        setup = "require('catppuccin').setup({ flavour = 'mocha' })";
        colorscheme = "catppuccin";
        # lualine ships no catppuccin theme file; "auto" reads the active colorscheme
        lualine = "auto";
      };
    };

    gruvbox-dark = {
      wallpaper = ../assets/wallpapers/gruvbox-dark/1-the-backwater.jpg;
      colors = {
        base00 = "#282828";
        base01 = "#1e1e1e";
        base02 = "#504945";
        base03 = "#665c54";
        base04 = "#bdae93";
        base05 = "#d5c4a1";
        base06 = "#ebdbb2";
        base07 = "#fbf1c7";
        base08 = "#fb4934";
        base09 = "#fe8019";
        base0A = "#fabd2f";
        base0B = "#b8bb26";
        base0C = "#8ec07c";
        base0D = "#83a598";
        base0E = "#d3869b";
        base0F = "#d65d0e";
      };
      neovim = {
        plugin = "https://github.com/ellisonleao/gruvbox.nvim";
        colorscheme = "gruvbox";
        lualine = "gruvbox";
      };
    };
  };
in
{
  inherit themes;

  homeModule =
    { lib, config, pkgs, ... }:
    {
      options.theme.name = lib.mkOption {
        type = lib.types.enum (builtins.attrNames themes);
        default = "tokyo-night";
        description = "Selected preset from home/theme.nix's `themes` list.";
      };

      config.stylix = {
        base16Scheme = themes.${config.theme.name}.colors;
        image = themes.${config.theme.name}.wallpaper;
      };

      # `theme-select` on PATH, no more cd-ing into scripts/ to run it
      config.home.packages = [
        (pkgs.writeShellScriptBin "theme-select" ''
          exec ${pkgs.bash}/bin/bash ${config.home.homeDirectory}/.src/nixos/scripts/theme-select.sh "$@"
        '')
      ];
    };
}
