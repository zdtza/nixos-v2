#!/usr/bin/env bash
# Pick a theme from home/theme.nix's `themes` list and write it into theme.name.
# Home-manager only, no sudo/nixos-rebuild -- run `sw` yourself after
# (see home/shell.nix's fish function).
set -euo pipefail

repo_dir=$HOME/.src/nixos
host_file="$repo_dir/hosts/legion/default.nix"
theme_file="$repo_dir/home/theme.nix"

mapfile -t names < <(nix eval --impure --json --expr "builtins.attrNames (import $theme_file).themes" | jq -r '.[]')
chosen=$(printf '%s\n' "${names[@]}" | fzf --prompt='Theme> ')
[[ -n "$chosen" ]] || exit 0

sed -i "s/theme\\.name = \".*\";/theme.name = \"$chosen\";/" "$host_file"

printf 'Set theme.name to %s. Run: sw\n' "$chosen"
