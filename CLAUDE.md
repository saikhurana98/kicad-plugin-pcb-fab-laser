# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A KiCad 9 pcbnew ActionPlugin that exports laser-fabrication SVGs (and optional PNGs) from a loaded board, targeting xTool-style diode lasers ablating spray-painted copper-clad boards.

## Install / run

```bash
./install.sh   # symlinks pcb_fab_laser/ into every ~/.local/share/kicad/<ver>/scripting/plugins/
```

Then in KiCad: **Tools → External Plugins → Refresh Plugins**, then run *PCB Fab Laser SVG Export*.

Because the install is a **symlink**, edits to the repo take effect after a Refresh Plugins (or a KiCad restart — pcbnew caches imported modules, so restart is the reliable way to pick up changes to already-imported modules).

There is no build, no test suite, and no linter configured. The only way to exercise the code is inside pcbnew — `import pcbnew` fails outside KiCad's Python. Plugin load errors surface in pcbnew's Python console, not stdout.

## Architecture

Three files, strict layering:

- `__init__.py` — KiCad's plugin loader imports this; it constructs and `.register()`s the plugin at import time.
- `action_plugin.py` — wx GUI only. `ExportDialog` gathers checkbox/DPI/outdir state into an `ExportOptions` dataclass, calls `LaserExporter.run()`, and reports the returned file list or the exception via `wx.MessageBox`. Contains no geometry logic.
- `exporter.py` — all geometry and file writing. Imports `pcbnew` but never `wx`, so it stays headless-testable in principle.

### Export model

Everything is flattened into `SHAPE_POLY_SET` (KiCad's polygon-set type) in internal units (IU, 1e6 per mm), then serialized to SVG by hand — no `pcbnew` plotter is used. Arcs are polygonized with a 5 µm chord error (`ARC_ERROR_IU`).

Three output files, named from the board filename stem:

| File | Content | Laser meaning |
|---|---|---|
| `<base>_ablate.svg` | `(board_outline − B.Cu) ∪ (B.SilkS ∩ board_outline)` | black = burn/ablate paint, leaving traces masked |
| `<base>_cut.svg` | Edge.Cuts outline, `fill=none`, red 0.1 mm stroke | cut path |
| `<base>_drill.svg` | one `<circle>`/`<ellipse>` per via and pad drill | drill targets |

Key point: **B.Cu is negative** (subtracted from the board outline) while **B.SilkS is positive** (added). Preserve this asymmetry — the laser removes paint everywhere black.

All three files share the **same bbox**, taken from the board outline, so they overlay 1:1 in the laser software. Coordinates are emitted in mm with a `viewBox` in mm and `width`/`height` in `mm` units. The `mirror` option flips X about the shared width (`x_mm = w_mm - x_mm`) and must be applied identically in `_poly_to_svg_path` and `_write_drill_svg`; if you add another writer, mirror there too or layers will not register.

### KiCad API compatibility shims

`exporter.py` wraps several pcbnew calls because signatures differ across KiCad versions:

- `_bool_add` / `_bool_sub` / `_bool_inter` / `_simplify` pass `PM_FAST` only when the enum exists.
- `_board_outline_poly` retries `GetBoardPolygonOutlines` without the second arg on `TypeError`.
- `_add_item_shape` retries `TransformShapeToPolygon` with a trailing `False` arg, then swallows failures.
- `_collect_drills` falls back from `GetDrillValue()` to `GetDrill()`.

When touching these, keep the try/except-narrow-then-broaden shape. Note the deliberate silent `except Exception: pass` in `_add_item_shape` and zone-fill collection — an unfillable zone or an unsupported item type must not abort a whole export.

### PNG rasterization

Out-of-process only. `_detect_rasterizer()` probes PATH in order `inkscape`, `rsvg-convert`, `magick`, `convert`; `_rasterize()` holds a per-tool argv. Adding a tool means editing both. Missing tool → hard `RuntimeError` (not a silent skip) when PNG was requested.

## Known gaps

- `defaults()` sets `icon_file_name` to `icon.png`, which does not exist in the package.
- `metadata.json` is a PCM manifest but the repo is not packaged for PCM; `install.sh` is the only install path, and the version there (`0.1.0`) is not referenced from code.
- `_collect_drills` does not deduplicate coincident holes and does not honor pad drill orientation (oval slots are emitted axis-aligned).
