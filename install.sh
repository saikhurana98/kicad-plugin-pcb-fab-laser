#!/usr/bin/env bash
set -euo pipefail

# Install plugin into every detected KiCad user scripting plugins dir.

SRC_DIR="$(cd "$(dirname "$0")" && pwd)/pcb_fab_laser"

if [ ! -d "$SRC_DIR" ]; then
  echo "Source dir not found: $SRC_DIR" >&2
  exit 1
fi

KICAD_ROOT="${HOME}/.local/share/kicad"
if [ ! -d "$KICAD_ROOT" ]; then
  echo "No KiCad config found at $KICAD_ROOT" >&2
  exit 1
fi

found=0
for ver_dir in "$KICAD_ROOT"/*/; do
  ver="$(basename "$ver_dir")"
  case "$ver" in
    [0-9]*.[0-9]*) ;;
    *) continue ;;
  esac
  dest_parent="${ver_dir}scripting/plugins"
  mkdir -p "$dest_parent"
  dest="$dest_parent/pcb_fab_laser"
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    rm -rf "$dest"
  fi
  ln -s "$SRC_DIR" "$dest"
  echo "Linked: $dest -> $SRC_DIR"
  found=1
done

if [ "$found" -eq 0 ]; then
  echo "No KiCad version dirs under $KICAD_ROOT" >&2
  exit 1
fi

echo
echo "In KiCad: Tools -> External Plugins -> Refresh Plugins"
echo "Then: Tools -> External Plugins -> 'PCB Fab Laser SVG Export'"
