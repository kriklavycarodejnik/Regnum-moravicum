# addons/gdUnit4/plugin.gd
@tool
extends EditorPlugin

func _enter_tree():
	add_autoload_singleton("GdUnitTest", "res://addons/gdUnit4/src/GdUnitTest.gd")

func _exit_tree():
	remove_autoload_singleton("GdUnitTest")