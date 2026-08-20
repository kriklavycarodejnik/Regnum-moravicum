# tools/capture_map_screenshot.gd
# Zachytí screenshot mapového viewportu a uloží ho ako PNG.
# Spustenie: godot --headless --path . -s res://tools/capture_map_screenshot.gd
extends SceneTree

const OUTPUT_NAME := "map_screenshot.png"

var _frames := 0
var _main: Node = null

func _init() -> void:
	print("Initializing screenshot capture...")
	# Defer loading so root and SceneTree are fully ready
	call_deferred("_setup")

func _setup() -> void:
	var main_scene: PackedScene = load("res://scenes/main/Main.tscn")
	if main_scene == null:
		print("FAIL: Nemožno načítať Main.tscn")
		quit(1)
		return

	_main = main_scene.instantiate()
	if _main == null:
		print("FAIL: Nemožno instantovať Main.tscn")
		quit(1)
		return

	root.add_child(_main)
	print("Main.tscn loaded, capturing screenshot in 6 frames...")

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 6:
		return true

	if _main == null:
		print("FAIL: _main is null")
		quit(1)
		return false

	# Find MapView
	var map_view: Node = _main.find_child("MapView", true, false)
	if map_view == null:
		print("FAIL: MapView not found in scene tree")
		quit(1)
		return false

	print("MapView found: %s" % map_view.get_path())

	# Capture screenshot of whole viewport
	var img: Image = root.get_texture().get_image()
	if img == null or img.is_empty():
		print("FAIL: Empty screenshot")
		quit(1)
		return false

	var save_path := "user://" + OUTPUT_NAME
	var err := img.save_png(save_path)
	if err != OK:
		print("FAIL: Cannot save PNG (error %d)" % err)
		quit(1)
		return false

	var abs_path := ProjectSettings.globalize_path(save_path)
	print("Screenshot saved to: %s (%dx%d)" % [abs_path, img.get_width(), img.get_height()])
	print("RESULT: PASS")
	quit(0)
	return false