#!/usr/bin/env bash
# Pick a theme from the themes/ folder, write it into theme.name, and activate
# it -- stylix (via home-manager) is the only thing that ever themes the
# desktop; this script just picks and activates.
#
# With no argument this fzf-picks interactively; with one it takes that theme
# name straight away, which is how quickshell's components/ThemePicker.qml
# applies a selection.
#
# Switching costs one `activate` (~0.7 s) and never invokes nix: the
# generations live under $link/<theme>, built by `build-themes` (fish function
# in home/shell.nix, `select-theme --build` here).
#
# That build is entirely manual: nothing in `sw`/`rb` or in a switch triggers
# it, so an ordinary rebuild stays as fast as it was, and a switch always
# serves whatever was built last -- even if the repo has moved on since. The
# next `sw` re-syncs the active theme from the working tree anyway; run
# `build-themes` when the *other* themes should pick up newer config.
#
# The one exception is a theme with no generation at all (never built, or a
# newly added themes/ folder): there is nothing to activate, so it is built.
set -euo pipefail

repo_dir=$HOME/.src/nixos
host=$(hostname)
host_file="$repo_dir/hosts/$host/default.nix"
link=$HOME/.cache/theme-generations

notify() { notify-send --app-name="Theme" "$@" || true; }

# A theme *is* a folder under themes/ (themes/default.nix builds the attrset
# with the same readDir), so list them directly -- no nix eval round trip.
list_themes() {
  find "$repo_dir/themes" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
}

current_theme() { sed -n 's/.*theme\.name = "\(.*\)";.*/\1/p' "$host_file"; }
set_theme() { sed -i "s/theme\.name = \".*\";/theme.name = \"$1\";/" "$host_file"; }

# One theme's generation, as an out-link at $link/<theme>. theme.name is the
# only input that differs between themes, so this rewrites it in the working
# tree and builds the normal flake attr -- no extra flake output to keep in
# sync. Always call through with_restore.
# ponytail: edits the repo in place while it runs, so don't `sw` in another
# terminal mid-build; export a worktree per theme if that ever collides.
build_one() {
  echo "Building $1..."
  set_theme "$1"
  git -C "$repo_dir" add --all
  nix build "$repo_dir#nixosConfigurations.$host.config.home-manager.users.$(id -un).home.activationPackage" \
    --out-link "$link/$1" --option warn-dirty false
}

# No names = every theme; names = just those (e.g. refreshing the one you are
# currently running, after editing config that affects it).
build_themes() {
  local theme
  if [[ $# -gt 0 ]]; then
    for theme in "$@"; do build_one "$theme"; done
    return
  fi
  while read -r theme; do
    build_one "$theme"
  done < <(list_themes)
}

# Runs a build with $link ready, restoring the selection the file had on entry
# even if the build fails.
with_restore() {
  # Global, not local: the EXIT trap runs after this function has returned, so
  # a local would be gone (and unbound, under set -u) by the time it fires.
  original=$(current_theme)
  trap 'set_theme "$original"; git -C "$repo_dir" add --all' EXIT
  # $link was a single link-farm symlink in an earlier version; it is a plain
  # directory of out-links now.
  if [[ -L $link ]]; then rm -f "$link"; fi
  mkdir -p "$link"
  "$@"
}

if [[ ${1:-} == --build ]]; then
  shift
  with_restore build_themes "$@"
  exit 0
fi

if [[ $# -gt 0 ]]; then
  chosen=$1
else
  chosen=$(list_themes | fzf)
fi
[[ -n "$chosen" ]] || exit 0

# The sed below rewrites a nix file from this name, so refuse anything that
# isn't an actual theme folder.
if [[ ! -d "$repo_dir/themes/$chosen" ]]; then
  printf 'No such theme: %s\n' "$chosen" >&2
  notify --urgency=critical "Theme switch failed" "No such theme: $chosen"
  exit 1
fi

set_theme "$chosen"
echo "Set theme.name to $chosen. Activating..."

if [[ ! -x "$link/$chosen/activate" ]]; then
  notify "Building $chosen" "Not built yet, this will take a while..."
  if ! with_restore build_one "$chosen"; then
    notify --urgency=critical "Theme switch failed" "build failed for $chosen"
    exit 1
  fi
fi

if ! "$link/$chosen/activate"; then
  notify --urgency=critical "Theme switch failed" "activation failed for $chosen"
  exit 1
fi
