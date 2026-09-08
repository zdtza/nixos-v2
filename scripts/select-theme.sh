#!/usr/bin/env bash
# Pick a theme from the themes/ folder, write it into theme.name, and activate
# it -- stylix (via home-manager) is the only thing that ever themes the
# desktop; this script just picks and rebuilds.
#
# With no argument this fzf-picks interactively; with one it takes that theme
# name straight away, which is how quickshell's components/ThemePicker.qml
# applies a selection -- the rebuild and its notifications stay in this one
# place either way.
#
# A plain `sw` costs ~9 s of nix eval plus up to ~9 s of building, every time,
# even switching back to a theme used a minute ago. Since theme.name is the
# *only* thing changing, the resulting home-manager generation for each theme
# is prebuilt in the background and kept under $cache_dir, keyed by the git
# tree hash of the repo as it would look with that theme selected. On a hit,
# switching is just `activate` (~0.7 s) and nix is never invoked. Any other
# edit in the repo changes the tree hash, so the cache can't serve a stale
# generation -- it simply misses and falls back to `sw`.
set -euo pipefail

repo_dir=$HOME/.src/nixos
host_file="$repo_dir/hosts/legion/default.nix"
cache_dir="$HOME/.cache/select-theme"
attr="nixosConfigurations.$(hostname).config.home-manager.users.$(id -un).home.activationPackage"

notify() { notify-send --app-name="Theme" "$@" || true; }

# Tree hash the repo index would have with theme.name = $1. Computed against a
# throwaway copy of the index so prebuilding other themes never touches the
# working tree the user is editing.
tree_for() {
  local blob index
  blob=$(sed "s/theme\.name = \".*\";/theme.name = \"$1\";/" "$host_file" |
    git -C "$repo_dir" hash-object -w --stdin)
  index=$(mktemp)
  cp "$(git -C "$repo_dir" rev-parse --git-path index)" "$index"
  GIT_INDEX_FILE=$index git -C "$repo_dir" update-index \
    --cacheinfo "100644,$blob,${host_file#"$repo_dir"/}"
  GIT_INDEX_FILE=$index git -C "$repo_dir" write-tree
  rm -f "$index"
}

# Build a theme's generation from an *export* of that tree rather than the
# working tree -- a dirty flake copies exactly the files git tracks, so the
# export hashes to the same store path (verified) while leaving the repo
# alone. Building from the tree is also what keeps the cache honest: the key
# and the thing stored under it come from the same object, so no concurrent
# write to the repo can make an entry lie about which theme it holds.
build_tree() {
  local tree=$1 theme=$2 worktree
  worktree=$(mktemp -d)
  git -C "$repo_dir" archive "$tree" | tar -x -C "$worktree"
  # Cheap guard against ever caching a generation under the wrong key again:
  # the export must actually select the theme this entry claims.
  grep -q "theme\.name = \"$theme\";" "$worktree/${host_file#"$repo_dir"/}" || {
    printf 'refusing to cache %s: export does not select %s\n' "$tree" "$theme" >&2
    rm -rf "$worktree"
    return 1
  }
  nix build "path:$worktree#$attr" --out-link "$cache_dir/$tree" --option warn-dirty false
  rm -rf "$worktree"
}

# A theme *is* a folder under themes/ (themes/default.nix builds the attrset
# with the same readDir), so list them directly -- no nix eval round trip.
list_themes() {
  find "$repo_dir/themes" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
}

# Fill the cache for every theme that isn't in it yet. Detached and behind a
# lock, so back-to-back switches don't stack up duplicate builds.
prebuild_others() {
  local theme tree
  flock -n 9 || exit 0
  # Out-links are GC roots; drop the ones no switch has used in a fortnight
  # (older repo states) so the store isn't pinned forever.
  find "$cache_dir" -maxdepth 1 -type l -mtime +14 -delete
  while read -r theme; do
    tree=$(tree_for "$theme")
    [[ -e "$cache_dir/$tree" ]] || build_tree "$tree" "$theme"
  done < <(list_themes)
}

mkdir -p "$cache_dir"

if [[ ${1:-} == --prebuild ]]; then
  exec 9>"$cache_dir/.lock"
  prebuild_others
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

# One switch at a time, and no prebuild running underneath it: the tree hash is
# taken from the repo a moment before the build reads it, so a second writer in
# that window (another switch, the shell picker) used to silently store the
# other theme's generation under this theme's key -- a lie the cache then
# served forever, since a hit is never re-checked.
exec 9>"$cache_dir/.lock"
flock 9

sed -i "s/theme\.name = \".*\";/theme.name = \"$chosen\";/" "$host_file"
# The tree hash below has to see the same files nix will, so stage first.
git -C "$repo_dir" add --all
tree=$(git -C "$repo_dir" write-tree)

echo "Set theme.name to $chosen. Activating..."

# Miss: build this exact tree, never the live working tree, so what lands in
# the cache is always what the key says it is. A miss is the slow path (nix
# eval + build, tens of seconds), so say so up front -- a cache hit switches
# in under a second and needs no announcement.
if [[ ! -e "$cache_dir/$tree/activate" ]]; then
  notify "Building $chosen" "Theme is not cached yet, this will take a while..."
  if ! build_tree "$tree" "$chosen"; then
    notify --urgency=critical "Theme switch failed" "build failed for $chosen"
    exit 1
  fi
fi

if ! "$cache_dir/$tree/activate"; then
  notify --urgency=critical "Theme switch failed" "activation failed for $chosen"
  exit 1
fi

# Warm the other themes for next time, detached -- the switch is already done.
# Hand the lock over first, or the prebuild's `flock -n` would just give up.
flock -u 9
setsid "$0" --prebuild >/dev/null 2>&1 &
