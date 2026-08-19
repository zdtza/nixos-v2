#!/usr/bin/env bash
# Installs this flake onto a new machine. Run as root, from a NixOS
# installer, with this repo checked out anywhere.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PERSIST_TARGET="/mnt/persist/home/cdt/Nix"

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this as root." >&2
  exit 1
fi

echo "Disk configured in modules/nixos/disk.nix:"
grep -A1 'disk.main' "$REPO_DIR/modules/nixos/disk.nix" | grep device
echo
lsblk -f
echo
read -rp "This disk will be WIPED. Type 'yes' to continue: " confirm
[ "$confirm" = "yes" ] || { echo "Aborted."; exit 1; }

nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
  --mode disko --flake "$REPO_DIR#legion"

mkdir -p "$(dirname "$PERSIST_TARGET")"
cp -r "$REPO_DIR" "$PERSIST_TARGET"

nixos-install --flake "$PERSIST_TARGET#legion" --root /mnt --no-root-password

echo
echo "Install complete. Log in as cdt with password 'changeme', then run: passwd"
