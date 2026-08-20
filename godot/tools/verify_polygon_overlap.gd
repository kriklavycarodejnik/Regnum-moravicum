# tools/verify_polygon_overlap.gd
# Overenie: všetkých 66 dvojíc žúp je disjunktných pri POLY_SCALE=0.56
# Spustenie: godot --headless --path . -s res://tools/verify_polygon_overlap.gd
extends SceneTree

const LAYOUT_PATH := "res://data/map_layout.json"
# Musí zodpovedať hodnotám v MapView.gd
const POLY_SCALE := 0.56
const JITTER_RANGE := 0.15
const JITTER_MAX := 1.0 + JITTER_RANGE  # 1.15

func _init() -> void:
	var f := FileAccess.open(LAYOUT_PATH, FileAccess.READ)
	if f == null:
		print("FAIL: Layout file not found")
		quit(1)
		return

	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		print("FAIL: Layout data is not a Dictionary")
		quit(1)
		return

	var layout: Dictionary = data.get("provinces", {})
	var view_size: Array = data.get("view_size", [900, 520])
	var W: float = float(view_size[0])
	var H: float = float(view_size[1])

	var prov_ids: Array = layout.keys()
	var n := prov_ids.size()

	if n != 12:
		print("FAIL: Expected 12 provinces, got %d" % n)
		quit(1)
		return

	print("=== Polygon overlap verification ===")
	print("Layout: %dx%d" % [W, H])
	print("POLY_SCALE: %.2f, JITTER_MAX: %.2f" % [POLY_SCALE, JITTER_MAX])
	print("Provinces: %d, pairs: %d" % [n, n * (n - 1) / 2])
	print("")

	var max_r := {}
	for pid in prov_ids:
		var node: Dictionary = layout[pid]
		var r: float = float(node.get("r", 30))
		max_r[pid] = r * POLY_SCALE * JITTER_MAX

	var failures := 0
	var min_gap := INF
	var min_pair := ""

	for i in range(n):
		for j in range(i + 1, n):
			var a: String = str(prov_ids[i])
			var b: String = str(prov_ids[j])
			var na: Dictionary = layout[a]
			var nb: Dictionary = layout[b]

			var ax: float = float(na.get("x", 0.5)) * W
			var ay: float = float(na.get("y", 0.5)) * H
			var bx: float = float(nb.get("x", 0.5)) * W
			var by: float = float(nb.get("y", 0.5)) * H

			var dx := bx - ax
			var dy := by - ay
			var dist := sqrt(dx * dx + dy * dy)

			var ra: float = max_r[a]
			var rb: float = max_r[b]
			var gap: float = dist - (ra + rb)

			if gap < min_gap:
				min_gap = gap
				min_pair = "%s-%s" % [a, b]

			if gap < 0.0:
				print("OVERLAP: %s (r=%d rmax=%.2f) <-> %s (r=%d rmax=%.2f) dist=%.2f gap=%.2f" % [
					a, int(na.get("r", 0)), ra, b, int(nb.get("r", 0)), rb, dist, gap
				])
				failures += 1

	print("\nClosest pair: %s (gap=%.4f px)" % [min_pair, min_gap])

	if failures == 0:
		print("\nRESULT: ALL %d pairs PASS — no polygon overlap at POLY_SCALE=%.2f" % [n * (n - 1) / 2, POLY_SCALE])
		quit(0)
	else:
		print("\nRESULT: %d overlapping pair(s) detected" % failures)
		quit(1)