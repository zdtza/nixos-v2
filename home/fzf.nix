{ config, ... }:

let
  # Same slot yazi/hyprland accent with (themes/*/accent).
  accent = config.lib.stylix.colors.withHashtag.${(import ../themes).themes.${config.theme.name}.accent};
  options = "--color=bg:-1,fg:-1,bg+:8,fg+:15,hl:${accent},hl+:${accent},pointer:${accent},marker:${accent},info:${accent},prompt:${accent},spinner:${accent},header:${accent}";
in
{
  # Disable Stylix so it doesn't overwrite the mapping below.
  stylix.targets.fzf.enable = false;

  programs.fzf.enable = true;

  # Home Manager normally serializes defaultOptions into FZF_DEFAULT_OPTS.
  home.sessionVariables.FZF_DEFAULT_OPTS_FILE = "${config.xdg.configHome}/fzf/options";
  xdg.configFile."fzf/options".text = ''
    ${options}
  '';
}
