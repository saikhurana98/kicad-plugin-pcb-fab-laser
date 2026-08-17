#!/usr/bin/env bash
set -euo pipefail

# Install the plugin into every detected KiCad user scripting plugins dir.
# Linux and macOS. Windows users: run install.ps1 in PowerShell instead.

SRC_DIR="$(cd "$(dirname "$0")" && pwd)/pcb_fab_laser"

if [ ! -d "$SRC_DIR" ]; then
  echo "Source dir not found: $SRC_DIR" >&2
  exit 1
fi

case "$(uname -s)" in
  Darwin) KICAD_ROOTS=("${HOME}/Documents/KiCad") ;;
  Linux)  KICAD_ROOTS=("${HOME}/.local/share/kicad") ;;
  *)      echo "Unsupported OS: $(uname -s). On Windows use install.ps1." >&2
          exit 1 ;;
esac

found=0
for KICAD_ROOT in "${KICAD_ROOTS[@]}"; do
  [ -d "$KICAD_ROOT" ] || continue
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
done

if [ "$found" -eq 0 ]; then
  echo "No KiCad version dirs found under: ${KICAD_ROOTS[*]}" >&2
  echo "Open pcbnew, then Tools -> External Plugins to locate your plugin folder," >&2
  echo "and copy pcb_fab_laser/ into it manually." >&2
  exit 1
fi

echo
echo "In KiCad: Tools -> External Plugins -> Refresh Plugins"
echo "Then: Tools -> External Plugins -> 'PCB Fab Laser SVG Export'"
