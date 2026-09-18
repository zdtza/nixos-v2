#!/usr/bin/env bash
# Pick a theme from the themes/ folder, write it into theme.name, and switch.
#
# With no argument this fzf-picks interactively; with one it takes that theme
# name straight away. Quickshell passes --background as well: the switch then
# runs in a detached tmux session and a notification can open that session.
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
mode=foreground
if [[ ${1:-} == --background || ${1:-} == --worker ]]; then
  mode=${1#--}
  shift
fi

# These are injected by the home-manager wrapper so the background path does
# not depend on an interactive shell's PATH.
theme_tmux=${THEME_TMUX:-tmux}
theme_terminal=${THEME_TERMINAL:-kitty}
theme_notify_send=${THEME_NOTIFY_SEND:-notify-send}
theme_session=theme-switch

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

# Keep the expensive switch off the shell UI. tmux retains the live output so
# the notification's default action can reveal the actual running process,
# rather than opening a second command that merely resembles it.
if [[ $mode == background ]]; then
  if ! "$theme_tmux" has-session -t "$theme_session" 2>/dev/null; then
    printf -v worker_command '%q ' "$BASH" "$0" --worker "$chosen"
    "$theme_tmux" new-session -d -s "$theme_session" "$worker_command"
  fi

  action=$("$theme_notify_send" --app-name="Theme Switch" \
    --action=default="Show progress" -t 3000 \
    "Theme switch running" "Click to view the rebuild process." || true)
  if [[ $action == default ]] && "$theme_tmux" has-session -t "$theme_session" 2>/dev/null; then
    "$theme_terminal" --class floating-terminal --title "Theme switch" \
      "$theme_tmux" attach-session -t "$theme_session" >/dev/null 2>&1 &
  fi
  exit 0
fi

# Report worker failures. Keep its tmux pane alive after opening it so the
# error remains readable until Enter is pressed.
if [[ $mode == worker ]]; then
  worker_exit() {
    status=$?
    trap - EXIT
    if (( status != 0 )); then
      action=$("$theme_notify_send" --app-name="Theme Switch" --urgency=critical \
        --action=default="Show error" -t 0 \
        "Theme switch failed" "Click to view the rebuild output." || true)
      if [[ $action == default ]]; then
        "$theme_terminal" --class floating-terminal --title "Theme switch failed" \
          "$theme_tmux" attach-session -t "$theme_session" >/dev/null 2>&1 &
        printf '\nTheme switch failed. Press Enter to close.\n'
        read -r || true
      fi
    fi
    exit "$status"
  }
  trap worker_exit EXIT
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
"$out/activate"
