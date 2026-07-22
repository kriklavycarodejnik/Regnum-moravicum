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
	if game_state != null:
		_init_province_religions()


func _init_province_religions() -> void:
	var provinces: Dictionary = game_state.provinces
	for province_id in provinces:
		var province: Dictionary = provinces[province_id]
		if not province.has("religion"):
			province["religion"] = "pagan"
	game_state.provinces = provinces


func process_religion() -> Dictionary:
	var report := {"type": "religion", "changes": [], "dominant_religion": "pagan"}
	var religion_counts: Dictionary = {}

	# Count religions
	var provinces: Dictionary = game_state.provinces
	for province_id in provinces:
		var province: Dictionary = provinces[province_id]
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
		var province_ids: Array = provinces.keys()
		var province_id: String = province_ids[rng.randi_range(0, province_ids.size() - 1)]
		var province: Dictionary = provinces[province_id]
		var new_religion: String = "christian" if str(province.get("religion", "pagan")) == "pagan" else "pagan"
		province["religion"] = new_religion
		report.changes.append({
			"province_id": province_id,
			"old_religion": province.get("religion", "pagan"),
			"new_religion": new_religion
		})
	game_state.provinces = provinces

	return report