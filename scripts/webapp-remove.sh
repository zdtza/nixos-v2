#!/usr/bin/env bash
# Remove a Chromium web app entry from home/apps.nix.
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
apps_file="$repo_dir/home/apps.nix"
[[ -f "$apps_file" ]] || {
  printf 'Missing %s\n' "$apps_file" >&2
  exit 1
}

mapfile -t entries < <(
  python3 - "$apps_file" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text()
for m in re.finditer(r'id = "(?P<id>[^"]+)";\s*\n\s*name = "(?P<name>[^"]+)";', text):
    print(f"{m['id']}\t{m['name']}")
PY
)
[[ ${#entries[@]} -gt 0 ]] || {
  printf 'No web apps installed.\n' >&2
  exit 1
}

selection=$(printf '%s\n' "${entries[@]}" | column -t -s $'\t' \
  | fzf --height=~40% --layout=reverse --no-multi --prompt='Remove> ') || exit 0
app_id=$(awk '{print $1}' <<< "$selection")
[[ -n "$app_id" ]] || exit 0

python3 - "$apps_file" "$app_id" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
app_id = sys.argv[2]
text = path.read_text()
pattern = re.compile(
    r'[ \t]*\{\s*\n\s*id = "' + re.escape(app_id) + r'";.*?\n[ \t]*\}\n',
    re.DOTALL,
)
new_text, count = pattern.subn("", text, count=1)
if count == 0:
    raise SystemExit(f"Could not find web app entry: {app_id}")
path.write_text(new_text)
PY

nixfmt "$apps_file"
printf '\nRemoved %s. Run: sudo nixos-rebuild switch --flake %s\n' "$app_id" "$repo_dir"
