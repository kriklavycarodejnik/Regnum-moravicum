# tools/capture_map_screenshot_wrapper.gd
# Wrapper script: loads Main.tscn (with autoloads), waits N frames, captures screenshot.
extends Control

const OUTPUT_NAME := "map_screenshot.png"

var _frames := 0

func _ready() -> void:
	print("Capture wrapper: loading Main.tscn...")
	var main_scene: PackedScene = load("res://scenes/main/Main.tscn")
	if main_scene == null:
		print("FAIL: Cannot load Main.tscn")
		return
	var main := main_scene.instantiate()
	if main == null:
		print("FAIL: Cannot instantiate Main.tscn")
		return
	add_child(main)
	print("Capture wrapper: Main.tscn loaded. Waiting frames for render...")

func _process(_delta: float) -> void:
	_frames += 1
	if _frames < 6:
		return

	# Capture the whole viewport
	var img: Image = get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		print("FAIL: Empty screenshot at frame %d" % _frames)
		return

	var save_path := "user://" + OUTPUT_NAME
	var err := img.save_png(save_path)
	if err != OK:
		print("FAIL: Cannot save PNG (error %d)" % err)
		return

	var abs_path := ProjectSettings.globalize_path(save_path)
	print("Screenshot saved to: %s (%dx%d)" % [abs_path, img.get_width(), img.get_height()])
	print("RESULT: PASS")
	get_tree().quit(0)