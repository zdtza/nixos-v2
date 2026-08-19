#!/usr/bin/env bash
# Installs this flake onto a new machine. Run as root, from a NixOS
# installer, with your cwd inside this flake's directory.
set -euo pipefail

REPO_DIR="$(pwd)"

if [ ! -f "$REPO_DIR/flake.nix" ]; then
  echo "Run this from inside the flake directory (where flake.nix lives)." >&2
  exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this as root." >&2
  exit 1
fi

read -rp "Username [cdt]: " USERNAME
USERNAME="${USERNAME:-cdt}"

PERSIST_TARGET="/mnt/persist/home/$USERNAME/Nix"

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
echo "Install complete. Log in as $USERNAME with password 'changeme', then run: passwd"
