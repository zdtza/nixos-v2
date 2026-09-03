{ config, ... }:

let
  colors = config.lib.stylix.colors.withHashtag;
in
{
  # disabling stylix in favour of custom styling
  stylix.targets.fzf.enable = false;

  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
    colors = {
      "bg" = colors.base00;
      "bg+" = colors.base01;
      "fg" = colors.base05;
      "fg+" = colors.base07;
      "header" = colors.base0E;
      "hl" = colors.base0E;
      "hl+" = colors.base0E;
      "info" = colors.base0E;
      "marker" = colors.base0E;
      "pointer" = colors.base0E;
      "prompt" = colors.base0E;
      "spinner" = colors.base0E;
    };
  };

  # re-exporting so a rebuild's fzf options reach the running uwsm session
  systemd.user.sessionVariables.FZF_DEFAULT_OPTS = config.home.sessionVariables.FZF_DEFAULT_OPTS;
}
