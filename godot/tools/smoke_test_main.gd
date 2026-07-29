# tools/smoke_test_main.gd
# Spusti cez: godot --headless --path . --scene res://scenes/main/Main.tscn --quit-after 4
# Tento súbor je len README — hlavný test beží ako --scene, nie -s.
# Overenie: godot --headless --path . --scene res://scenes/main/Main.tscn --quit-after 4 2>&1 | grep -E "(Parse|SCRIPT ERROR|SMOKE_MAIN)"
# Ak výstup neobsahuje Parse/SCRIPT ERROR, Main.tscn sa načítal bez chýb.