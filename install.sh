#!/usr/bin/env bash
set -euo pipefail

# Install plugin into every detected KiCad user scripting plugins dir.

SRC_DIR="$(cd "$(dirname "$0")" && pwd)/pcb_fab_laser"

if [ ! -d "$SRC_DIR" ]; then
  echo "Source dir not found: $SRC_DIR" >&2
  exit 1
fi

# KiCad's user data root differs by platform:
#   Linux:   ~/.local/share/kicad/<ver>/scripting/plugins
#   macOS:   ~/Documents/KiCad/<ver>/scripting/plugins
#   Windows: %USERPROFILE%/Documents/KiCad/<ver>/scripting/plugins (Git Bash)
KICAD_ROOTS=()
case "$(uname -s)" in
  Darwin)
    KICAD_ROOTS+=("${HOME}/Documents/KiCad")
    ;;
  Linux)
    KICAD_ROOTS+=("${HOME}/.local/share/kicad")
    ;;
  MINGW*|MSYS*|CYGWIN*)
    KICAD_ROOTS+=("${HOME}/Documents/KiCad")
    ;;
  *)
    # Unknown platform: try both known layouts.
    KICAD_ROOTS+=("${HOME}/Documents/KiCad" "${HOME}/.local/share/kicad")
    ;;
esac

# Keep only roots that actually exist.
existing_roots=()
for root in "${KICAD_ROOTS[@]}"; do
  [ -d "$root" ] && existing_roots+=("$root")
done

if [ "${#existing_roots[@]}" -eq 0 ]; then
  echo "No KiCad user data dir found. Looked in:" >&2
  for root in "${KICAD_ROOTS[@]}"; do
    echo "  $root" >&2
  done
  exit 1
fi

link_or_copy() {
  # ln -s where supported; fall back to a copy (e.g. Windows without symlink priv).
  local src="$1" dest="$2"
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    rm -rf "$dest"
  fi
  if ln -s "$src" "$dest" 2>/dev/null; then
    echo "Linked: $dest -> $src"
  else
    cp -R "$src" "$dest"
    echo "Copied: $src -> $dest (symlink unavailable; re-run install.sh after edits)"
  fi
}

found=0
for KICAD_ROOT in "${existing_roots[@]}"; do
  for ver_dir in "$KICAD_ROOT"/*/; do
    [ -d "$ver_dir" ] || continue
    ver="$(basename "$ver_dir")"
    case "$ver" in
      [0-9]*.[0-9]*) ;;
      *) continue ;;
    esac
    dest_parent="${ver_dir}scripting/plugins"
    mkdir -p "$dest_parent"
    link_or_copy "$SRC_DIR" "$dest_parent/pcb_fab_laser"
    found=1
  done
done

if [ "$found" -eq 0 ]; then
  echo "No KiCad version dirs (e.g. 9.0, 10.0) found under:" >&2
  for root in "${existing_roots[@]}"; do
    echo "  $root" >&2
  done
  exit 1
fi

echo
echo "In KiCad: Tools -> External Plugins -> Refresh Plugins"
echo "Then: Tools -> External Plugins -> 'PCB Fab Laser SVG Export'"
