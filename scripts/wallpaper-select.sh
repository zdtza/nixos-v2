#!/usr/bin/env bash
# Pick a wallpaper from the active theme's assets/wallpapers/<theme> folder
# (folder name matches the theme name exactly, see home/theme.nix) and write
# it into that theme's `wallpaper` line -- so it survives the next `sw` and
# a fresh install -- then apply it live right now via push-wallpaper-live.sh,
# no `sw` required.
set -euo pipefail

repo_dir=$HOME/.src/nixos
host_file="$repo_dir/hosts/legion/default.nix"
theme_file="$repo_dir/home/theme.nix"

theme_name=$(grep -oP '(?<=theme\.name = ")[^"]+' "$host_file")
wallpaper_dir="$repo_dir/assets/wallpapers/$theme_name"

mapfile -t files < <(find "$wallpaper_dir" -maxdepth 1 -type f -printf '%f\n' | sort)
chosen=$(printf '%s\n' "${files[@]}" | fzf)
[[ -n "$chosen" ]] || exit 0

sed -i "/^    $theme_name = {\$/,/^    };\$/ s|^\(      wallpaper = \).*;|\1../assets/wallpapers/$theme_name/$chosen;|" "$theme_file"

"$repo_dir/scripts/push-wallpaper-live.sh" "$wallpaper_dir/$chosen"

printf 'Set wallpaper to %s\n' "$chosen"
