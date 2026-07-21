# scripts/managers/ReligionManager.gd
class_name ReligionManager
extends RefCounted

const GAME_STATE := preload("res://scripts/core/GameState.gd")

var game_state
var rng: RandomNumberGenerator


func _init(state: RefCounted = null, rng_ref: RandomNumberGenerator = null) -> void:
	if state != null:
		game_state = state
	if rng_ref != null:
		rng = rng_ref
	_init_province_religions()


func _init_province_religions() -> void:
	var provinces_conversion: Dictionary = game_state.get("provinces") or {}
	for province_id in provinces_conversion:
		var province: Dictionary = provinces_conversion[province_id]
		if not province.has("religion"):
			province["religion"] = "pagan"


func process_religion() -> Dictionary:
	var report := {"type": "religion", "changes": [], "dominant_religion": "pagan"}
	var religion_counts: Dictionary = {}

	# Count religions
	var provinces_conversion: Dictionary = game_state.get("provinces") or {}
	for province_id in provinces_conversion:
		var province: Dictionary = provinces_conversion[province_id]
		var religion: String = str(province.get("religion", "pagan"))
		religion_counts[religion] = int(religion_counts.get(religion, 0)) + 1

	# Determine dominant religion
	var max_count: int = 0
	for religion in religion_counts:
		if religion_counts[religion] > max_count:
			max_count = religion_counts[religion]
			report.dominant_religion = religion

	# Random conversion
	if rng.randf_range(0.0, 1.0) < 0.05:
		var provinces_conversion_2: Dictionary = game_state.get("provinces") or {}
		var province_ids: Array = provinces_conversion_2.keys()
		for province_id in province_ids:
			var province: Dictionary = provinces_conversion_2[province_id]
			var new_religion: String = "christian" if str(province.get("religion", "pagan")) == "pagan" else "pagan"
			province["religion"] = new_religion
			report.changes.append({
				"province_id": province_id,
				"old_religion": province.get("religion", "pagan"),
				"new_religion": new_religion
			})

	return report