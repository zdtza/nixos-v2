#!/usr/bin/env bash
# Pick a wallpaper from the active theme's themes/<theme>/wallpapers folder
# (folder name matches the theme name exactly, see themes/default.nix) and
# write it into that theme's `wallpaper` line -- so it survives the next `sw` and
# a fresh install -- then apply it live right now, no `sw` required.
#
# With no argument this fzf-picks interactively; with one it takes that file
# (path or bare name) straight away, which is how quickshell's
# components/WallpaperPicker.qml applies a selection -- persistence stays in
# this one place either way.
set -euo pipefail

repo_dir=$HOME/.src/nixos
host_file="$repo_dir/hosts/legion/default.nix"
theme_name=$(grep -oP '(?<=theme\.name = ")[^"]+' "$host_file")
theme_file="$repo_dir/themes/$theme_name/default.nix"
wallpaper_dir="$repo_dir/themes/$theme_name/wallpapers"

if [[ $# -gt 0 ]]; then
  chosen=$(basename -- "$1")
else
  mapfile -t files < <(find "$wallpaper_dir" -maxdepth 1 -type f -printf '%f\n' | sort)
  chosen=$(printf '%s\n' "${files[@]}" | fzf)
fi
[[ -n "$chosen" ]] || exit 0

# The sed below rewrites a nix file from this name, so refuse anything that
# isn't an actual file sitting in the theme's wallpaper folder.
if [[ ! -f "$wallpaper_dir/$chosen" ]]; then
  printf 'No such wallpaper in %s: %s\n' "$wallpaper_dir" "$chosen" >&2
  exit 1
fi

# One theme per file now, so this is the only `wallpaper =` line in it.
sed -i "s|^\(  wallpaper = \).*;|\1./wallpapers/$chosen;|" "$theme_file"

# Push it live to quickshell (the only wallpaper renderer now, see
# config/quickshell/components/Background.qml) -- the one deliberate exception
# to "stylix/`sw` is the only thing that themes the desktop": wallpaper-switch
# animations are the whole point of quickshell owning it directly.
# ~/.cache/quickshell/theme.json is plain, machine-written JSON that a
# FileView{watchChanges:true} in Theme.qml watches -- patch its "wallpaper"
# field in place (`cat >`, not `mv`, to keep the same inode the watch is on,
# see home/quickshell.nix).
quickshell_theme="$HOME/.cache/quickshell/theme.json"
if [[ -f "$quickshell_theme" ]]; then
  tmp=$(mktemp)
  jq --arg w "$wallpaper_dir/$chosen" '.wallpaper = $w' "$quickshell_theme" >"$tmp" && cat "$tmp" >"$quickshell_theme"
  rm -f "$tmp"
fi

printf 'Set wallpaper to %s\n' "$chosen"
