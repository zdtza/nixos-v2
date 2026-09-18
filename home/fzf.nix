{ config, ... }:

let
  # Same slot yazi/hyprland accent with (themes/*/accent).
  accent = config.lib.stylix.colors.withHashtag.${(import ../themes).themes.${config.theme.name}.accent};
  options = "--color=bg:-1,fg:-1,bg+:8,fg+:15,hl:${accent},hl+:${accent},pointer:${accent},marker:${accent},info:${accent},prompt:${accent},spinner:${accent},header:${accent}";
in
{
  # Disable Stylix so it doesn't overwrite the mapping below
  stylix.targets.fzf.enable = false;

  programs.fzf.enable = true;

  # Home Manager normally serializes defaultOptions into FZF_DEFAULT_OPTS.
  # Yazi inherits that value once at startup, so its built-in fzf plugin kept
  # the old palette after Yazi's own theme had been reloaded in place. Point
  # fzf at a stable config path instead: every invocation reads the symlink's
  # current generation, including invocations from an already-running Yazi.
  home.sessionVariables.FZF_DEFAULT_OPTS_FILE = "${config.xdg.configHome}/fzf/options";
  xdg.configFile."fzf/options".text = ''
    ${options}
  '';
}
