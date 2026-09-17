{ config, ... }:

let
  # Same slot yazi/hyprland accent with (themes/*/accent).
  accent = config.lib.stylix.colors.withHashtag.${(import ../themes).themes.${config.theme.name}.accent};
in
{
  # Disable Stylix so it doesn't overwrite the mapping below
  stylix.targets.fzf.enable = false;

  programs.fzf = {
    enable = true;
    # bg/fg default to the terminal's (-1), bg+ is ANSI 8 (selection bar),
    # fg+ ANSI 15; everything fzf highlights takes the theme accent.
    defaultOptions = [
      "--color=bg:-1,fg:-1,bg+:8,fg+:15,hl:${accent},hl+:${accent},pointer:${accent},marker:${accent},info:${accent},prompt:${accent},spinner:${accent},header:${accent}"
    ];
  };
}
