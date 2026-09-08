{ config, pkgs, lib, ... }:

let
  vscodeTheme = (import ../themes).themes.${config.theme.name}.vscode;
in
{
  # VS Code watches settings.json itself and hot-applies external edits --
  # workbench.colorTheme included -- so patching the file on `sw` is enough,
  # no restart/signal needed. It's hand-edited from the GUI constantly and
  # is JSONC in practice (this file already carries a trailing comma), so a
  # strict JSON parser would choke on it and reformat the rest; sed-patch
  # just the one key in place instead, same approach as omarchy's own
  # omarchy-theme-set-vscode.
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
