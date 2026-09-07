#!/usr/bin/env bash
# Push a wallpaper file live to quickshell (the only wallpaper renderer now
# -- see config/quickshell/components/Background.qml), no `sw` required.
# Called by wallpaper-select.sh -- the one deliberate exception to "stylix/
# `sw` is the only thing that themes the desktop": wallpaper-switch
# animations are the whole point of quickshell owning it directly (see
# Background.qml), so it keeps this instant live path.
#
# ~/.cache/quickshell/theme.json is plain, machine-written JSON that a
# FileView{watchChanges:true} in Theme.qml watches -- patch its "wallpaper"
# field in place (`cat >`, not `mv`, to keep the same inode the watch is on,
# see home/quickshell.nix).
set -euo pipefail

chosen_path=$1
quickshell_theme="$HOME/.cache/quickshell/theme.json"

if [[ -f "$quickshell_theme" ]]; then
  tmp=$(mktemp)
  jq --arg w "$chosen_path" '.wallpaper = $w' "$quickshell_theme" >"$tmp" && cat "$tmp" >"$quickshell_theme"
  rm -f "$tmp"
fi
