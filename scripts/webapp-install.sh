#!/usr/bin/env bash
# Add a Chromium web app entry to home/apps.nix.
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
apps_file="$repo_dir/home/apps.nix"
[[ -f "$apps_file" ]] || {
  printf 'Missing %s\n' "$apps_file" >&2
  exit 1
}

read -r -p 'Web App Name: ' app_name
read -r -p 'Web App URL: ' app_url
read -r -p 'Private session? [y/N]: ' private_answer
[[ "$private_answer" =~ ^[Yy] ]] && app_private=true || app_private=false

[[ -n "$app_name" && -n "$app_url" ]] || {
  printf 'Name and URL are required.\n' >&2
  exit 1
}
[[ "$app_url" =~ ^[a-zA-Z][a-zA-Z0-9+.-]*:// ]] || app_url="https://$app_url"
[[ "$app_url" =~ ^https?:// ]] || {
  printf 'Only HTTP and HTTPS URLs are supported.\n' >&2
  exit 1
}

app_id=$(printf '%s' "$app_name" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')
[[ -n "$app_id" ]] || app_id="webapp-$(date +%s)"
base_id="$app_id"
suffix=2
while grep -Fq "id = \"$app_id\";" "$apps_file"; do
  app_id="$base_id-$suffix"
  ((suffix += 1))
done

page_file=$(mktemp)
icon_file=$(mktemp)
trap 'rm -f -- "$page_file" "$icon_file"' EXIT

curl -fsSL --max-time 2 --user-agent 'Mozilla/5.0' "$app_url" 2>/dev/null \
  | head -c 200000 > "$page_file" || true

mapfile -t icon_candidates < <(
  python3 - "$app_url" "$page_file" <<'PY'
import sys
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urljoin, urlsplit, urlunsplit

class Icons(HTMLParser):
    def __init__(self):
        super().__init__()
        self.icons = []

    def handle_starttag(self, tag, attrs):
        if tag.lower() != "link":
            return
        values = dict(attrs)
        rel = values.get("rel", "").lower()
        href = values.get("href")
        if href and "apple-touch-icon" in rel:
            self.icons.append(href)

url = sys.argv[1]
parser = Icons()
try:
    parser.feed(Path(sys.argv[2]).read_text(errors="ignore")[:200000])
except OSError:
    pass
for href in parser.icons:
    candidate = urljoin(url, href)
    if candidate.startswith(("http://", "https://")):
        print(candidate)
parts = urlsplit(url)
origin = f"{parts.scheme}://{parts.netloc}"
url_without_fragment = urlunsplit((parts.scheme, parts.netloc, parts.path, parts.query, ""))
print(f"{origin}/apple-touch-icon.png")
print(f"https://www.google.com/s2/favicons?domain={url_without_fragment}&sz=256")
PY
)

icon_url=''
for candidate in "${icon_candidates[@]}"; do
  if curl -fsSL --max-time 10 --user-agent 'Mozilla/5.0' -o "$icon_file" "$candidate" 2>/dev/null \
    && [[ -s "$icon_file" ]] \
    && [[ $(file -b --mime-type "$icon_file") == image/* ]]; then
    icon_url="$candidate"
    break
  fi
done
[[ -n "$icon_url" ]] || {
  printf 'Could not find a usable site icon.\n' >&2
  exit 1
}
icon_hash=$(nix hash file "$icon_file")

python3 - "$apps_file" "$app_id" "$app_name" "$app_url" "$app_private" "$icon_url" "$icon_hash" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
app_id, name, url, private, icon_url, icon_hash = sys.argv[2:]
marker = "    # WEBAPPS"
text = path.read_text()
if marker not in text:
    raise SystemExit(f"Web app marker is missing: {path}")
q = json.dumps
entry = (
    "    {\n"
    f"      id = {q(app_id)};\n"
    f"      name = {q(name)};\n"
    f"      url = {q(url)};\n"
    f"      private = {private};\n"
    f"      iconUrl = {q(icon_url)};\n"
    f"      iconHash = {q(icon_hash)};\n"
    "    }\n"
)
path.write_text(text.replace(marker, entry + marker, 1))
PY

nixfmt "$apps_file"
printf '\nAdded %s (%s). Run: sudo nixos-rebuild switch --flake %s\n' "$app_name" "$app_id" "$repo_dir"
