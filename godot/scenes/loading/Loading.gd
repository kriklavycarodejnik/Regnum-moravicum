# scenes/loading/Loading.gd
# Loading screen medzi MainMenu a Main/Briefing.
# Zobrazí náhodný hero asset, kým sa načíta cieľová scéna.
extends Control

const HERO_ASSETS := [
	"nitra_master_hero",
	"devin_master_fortress",
	"bratislava_master_river",
	"moravian_court_interior",
	"mojmir_ii_master_portrait",
	"regnum_visual_style_master",
]

var _target_scene: String = ""


func _ready() -> void:
	# Pick random hero asset
	var cat = get_node_or_null("/root/ArtCatalog")
	if cat == null:
		# No ArtCatalog — just show text
		pass
	else:
		var bg: TextureRect = $BackgroundArt if has_node("BackgroundArt") else null
		if bg:
			var pool: Array = HERO_ASSETS.duplicate()
			pool.shuffle()
			for art_id in pool:
				var tex: Texture2D = cat.safe_texture(art_id)
				if tex != null:
					bg.texture = tex
					bg.modulate = Color(1, 1, 1, 0.25)
					break

	# Start deferred transition to target scene
	call_deferred("_do_transition")


func set_target(scene_path: String) -> void:
	_target_scene = scene_path


func _do_transition() -> void:
	if _target_scene == "":
		# Default: Main.tscn
		_target_scene = "res://scenes/main/Main.tscn"
	get_tree().change_scene_to_file(_target_scene)