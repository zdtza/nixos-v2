{ config, pkgs, lib, ... }:

let
  # Escaped for the single-quoted sed script below: theme names carry
  # apostrophes ("Retro '82"), which would otherwise close the quote.
  vscodeTheme = builtins.replaceStrings [ "'" ] [ "'\\''" ] (import ../themes).themes.${config.theme.name}.vscode;
in
{
  # VS Code hot-reloads settings.json. Patch only the theme key to preserve
  # user edits, comments and trailing commas in this JSONC file.
  home.activation.vscodeTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings="$HOME/.config/Code/User/settings.json"
    if [ -f "$settings" ]; then
      if ! grep -q '"workbench.colorTheme"' "$settings"; then
        run ${pkgs.gnused}/bin/sed -i --follow-symlinks -E \
          '0,/\{/{s/\{/{ "workbench.colorTheme": "",/}' "$settings"
      fi
      run ${pkgs.gnused}/bin/sed -i --follow-symlinks -E \
        's|("workbench\.colorTheme"[[:space:]]*:[[:space:]]*")[^"]*(")|\1${vscodeTheme}\2|' \
        "$settings"
    fi
  '';
}
