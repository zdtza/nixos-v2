{ config, ... }:

let
  colors = config.lib.stylix.colors.withHashtag;
  accent = colors.base0D;
in
{
  # custom colors below use a single accent color instead of stylix's
  # default per-slot base16 mapping
  stylix.targets.fzf.enable = false;

  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
    colors = {
      "bg" = colors.base00;
      "bg+" = colors.base01;
      "fg" = colors.base05;
      "fg+" = colors.base07;
      "header" = accent;
      "hl" = accent;
      "hl+" = accent;
      "info" = accent;
      "marker" = accent;
      "pointer" = accent;
      "prompt" = accent;
      "spinner" = accent;
    };
  };

  # session variables inherited by UWSM don't change during activation;
  # re-export so a rebuild's new FZF_DEFAULT_OPTS reaches the running session
  systemd.user.sessionVariables.FZF_DEFAULT_OPTS = config.home.sessionVariables.FZF_DEFAULT_OPTS;
}
