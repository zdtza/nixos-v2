#!/usr/bin/env bash
# Pick a theme from home/theme.nix's `themes` list and write it into
# theme.name, then run the real `sw` -- stylix (via home-manager) is the
# only thing that ever themes the desktop; this script just picks and
# rebuilds, same as running `theme-select` by hand followed by `sw` used to
# be. `sw` is a fish function (home/shell.nix), not a binary, so shell out
# to fish rather than re-typing its nix build invocation here too.
set -euo pipefail

repo_dir=$HOME/.src/nixos
host_file="$repo_dir/hosts/legion/default.nix"
theme_file="$repo_dir/home/theme.nix"

mapfile -t names < <(nix eval --impure --json --expr "builtins.attrNames (import $theme_file).themes" | jq -r '.[]')
chosen=$(printf '%s\n' "${names[@]}" | fzf)
[[ -n "$chosen" ]] || exit 0

sed -i "s/theme\\.name = \".*\";/theme.name = \"$chosen\";/" "$host_file"
echo "Set theme.name to $chosen. Running sw..."

fish -c sw
