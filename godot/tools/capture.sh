#!/bin/bash
# capture.sh — spustí screenshot trace pre vizuálnu QA.
#
# DÔLEŽITÉ: musí bežať display-backed (NIE --headless). Headless Godot
# nevytvára framebuffer, takže root.get_texture() vracia null a capture zlyhá.
#
# Usage:
#   cd godot && bash tools/capture.sh
#
# Výstup: 7 PNG do godot/tools/screenshots/ (01_MENU ... 07_MAPA_PO_TAHU),
# každý beh prepíše predchádzajúcu sadu.

set -euo pipefail

# Cesta do adresára godot/ nezávisle od toho, odkiaľ sa skript spúšťa
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GODOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$GODOT_DIR"

# Čistá sada pred behom (neprepisovať staré screenshoty zo starších trás)
rm -f tools/screenshots/*.png

echo "=== Regnum Moravicum — Screenshot Trace (display-backed) ==="
godot --disable-vsync -s res://tools/screenshot_trace.gd --quit-after 240 "$@"

echo ""
echo "Hotovo. Screenshoty:"
ls -1 tools/screenshots/*.png
