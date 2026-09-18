#!/usr/bin/env bash
# Pick a theme from the themes/ folder, write it into theme.name, and switch.
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

# These are injected by the home-manager wrapper so the background path does not depend on an interactive shell's PATH.
theme_tmux=${THEME_TMUX:-tmux}
theme_terminal=${THEME_TERMINAL:-kitty}
theme_notify_send=${THEME_NOTIFY_SEND:-notify-send}
theme_session=theme-switch

# A theme *is* a folder under themes/, so list them directly -- no nix eval round trip.
list_themes() {
  find "$repo_dir/themes" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
}

set_theme() { sed -i "s/theme\.name = \".*\";/theme.name = \"$1\";/" "$host_file"; }
stage() { git -C "$repo_dir" add --all; }

chosen=${1:-$(list_themes | fzf)}
[[ -n "$chosen" ]] || exit 0

# The sed above rewrites a nix file from this name, so refuse anything that isn't an actual theme folder.
if [[ ! -d "$repo_dir/themes/$chosen" ]]; then
  printf 'No such theme: %s\n' "$chosen" >&2
  exit 1
fi

# Run background switches in tmux so their output remains accessible.
if [[ $mode == background ]]; then
  if ! "$theme_tmux" has-session -t "$theme_session" 2>/dev/null; then
    printf -v worker_command '%q ' "$BASH" "$0" --worker "$chosen"
    "$theme_tmux" new-session -d -s "$theme_session" "$worker_command"
  fi

  action=$("$theme_notify_send" --app-name="Theme Switch" \
    --action=default="Show progress" -t 10000 \
    "Theme switch running" "Click to view the rebuild process." || true)
  if [[ $action == default ]] && "$theme_tmux" has-session -t "$theme_session" 2>/dev/null; then
    "$theme_terminal" --class floating-terminal --title "Theme switch" \
      "$theme_tmux" attach-session -t "$theme_session" >/dev/null 2>&1 &
  fi
  exit 0
fi

# Report worker failures.
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

# theme.name is the only input that differs between themes, so blanking it out gives a hash of everything *else*.
set_theme "__stamp__"
stage
stamp=$(git -C "$repo_dir" write-tree)

set_theme "$chosen"
stage

out=$cache/$stamp/$chosen
mkdir -p "$cache"
# Remove generations built from older configurations.
find "$cache" -mindepth 1 -maxdepth 1 ! -name "$stamp" -exec rm -rf {} +

if [[ ! -x "$out/activate" ]]; then
  echo "Building $chosen..."
  nix build \
    "$repo_dir#nixosConfigurations.$host.config.home-manager.users.$(id -un).home.activationPackage" \
    --out-link "$out" --option warn-dirty false
fi

echo "Set theme.name to $chosen. Activating..."
"$out/activate"
