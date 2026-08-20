{ config, ... }:

let
  colors = config.lib.stylix.colors.withHashtag;
in
{
  stylix.targets.fzf.enable = false;

  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
    colors = {
      "bg" = colors.base00;
      "bg+" = colors.base01;
      "fg" = colors.base05;
      "fg+" = colors.base07;
      "header" = colors.base0D;
      "hl" = colors.base0D;
      "hl+" = colors.base0D;
      "info" = colors.base0D;
      "marker" = colors.base0D;
      "pointer" = colors.base0D;
      "prompt" = colors.base0D;
      "spinner" = colors.base0D;
    };
  };

  # session variables inherited by UWSM don't change during activation;
  # re-export so a rebuild's new FZF_DEFAULT_OPTS reaches the running session
  systemd.user.sessionVariables.FZF_DEFAULT_OPTS = config.home.sessionVariables.FZF_DEFAULT_OPTS;
}
