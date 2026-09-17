#!/usr/bin/env bash
# Pick a theme from the themes/ folder, write it into theme.name, and switch.
#
# With no argument this fzf-picks interactively; with one it takes that theme
# name straight away, which is how quickshell's components/ThemePicker.qml
# applies a selection (it opens a terminal running this).
#
# The switch is the same home-manager activation `sw` does (home/shell.nix) --
# stylix, via home-manager, is the only thing that themes the desktop.
#
# Each theme's generation is cached as an out-link under
# ~/.cache/theme-generations/<stamp>/<theme>, so switching back to a theme used
# since the last rebuild is instant and never invokes nix. <stamp> is the git
# tree hash of the repo with theme.name neutralized, i.e. "this config, any
# theme": edit anything (or update the flake) and every theme's cache entry
# misses once, exactly as asked. The out-link doubles as a GC root, so the
# cached generation survives nix-collect-garbage.
set -euo pipefail

repo_dir=$HOME/.src/nixos
host=$(hostname)
host_file="$repo_dir/hosts/$host/default.nix"
cache=$HOME/.cache/theme-generations

# A theme *is* a folder under themes/ (themes/default.nix builds the attrset
# with the same readDir), so list them directly -- no nix eval round trip.
list_themes() {
  find "$repo_dir/themes" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
}

set_theme() { sed -i "s/theme\.name = \".*\";/theme.name = \"$1\";/" "$host_file"; }
stage() { git -C "$repo_dir" add --all; }

chosen=${1:-$(list_themes | fzf)}
[[ -n "$chosen" ]] || exit 0

# The sed above rewrites a nix file from this name, so refuse anything that
# isn't an actual theme folder.
if [[ ! -d "$repo_dir/themes/$chosen" ]]; then
  printf 'No such theme: %s\n' "$chosen" >&2
  exit 1
fi

# theme.name is the only input that differs between themes, so blanking it out
# gives a hash of everything *else* -- the same stamp for every theme.
set_theme "__stamp__"
stage
stamp=$(git -C "$repo_dir" write-tree)

set_theme "$chosen"
stage

out=$cache/$stamp/$chosen
mkdir -p "$cache"
# Anything under another stamp was built from config that no longer exists.
# ponytail: drops the whole tree on any edit, so a quick A->B->A after a
# rebuild costs two builds; keep the last N stamps if that ever chafes.
find "$cache" -mindepth 1 -maxdepth 1 ! -name "$stamp" -exec rm -rf {} +

if [[ ! -x "$out/activate" ]]; then
  echo "Building $chosen..."
  nix build \
    "$repo_dir#nixosConfigurations.$host.config.home-manager.users.$(id -un).home.activationPackage" \
    --out-link "$out" --option warn-dirty false
fi

echo "Set theme.name to $chosen. Activating..."
exec "$out/activate"
