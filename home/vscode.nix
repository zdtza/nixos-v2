{
  config,
  pkgs,
  lib,
  ...
}:

let
  # Escaped for the single-quoted sed script below: theme names carry apostrophes ("Retro '82"), which would otherwise close the quote.
  vscodeTheme =
    builtins.replaceStrings [ "'" ] [ "'\\''" ]
      (import ../themes).themes.${config.theme.name}.vscode;
in
{
  # VS Code hot-reloads settings.json.
  home.activation.vscodeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings="$HOME/.config/Code/User/settings.json"
    if [ -f "$settings" ]; then
      if ! grep -q '"workbench.colorTheme"' "$settings"; then
        run ${pkgs.gnused}/bin/sed -i --follow-symlinks -E \
          '0,/\{/{s/\{/{ "workbench.colorTheme": "",/}' "$settings"
      fi
      if ! grep -q '"editor.fontFamily"' "$settings"; then
        run ${pkgs.gnused}/bin/sed -i --follow-symlinks -E \
          '0,/\{/{s/\{/{ "editor.fontFamily": "",/}' "$settings"
      fi
      run ${pkgs.gnused}/bin/sed -i --follow-symlinks -E \
        -e 's|("workbench\.colorTheme"[[:space:]]*:[[:space:]]*")[^"]*(")|\1${vscodeTheme}\2|' \
        -e 's|("editor\.fontFamily"[[:space:]]*:[[:space:]]*")[^"]*(")|\1JetBrainsMono Nerd Font\2|' \
        "$settings"
    fi
  '';
}
