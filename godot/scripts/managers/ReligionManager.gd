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
			province["religion"] = 50
	game_state.provinces = provinces


func process_religion() -> Dictionary:
	var report := {"type": "religion", "changes": [], "dominant_religion": "pagan"}
	var religion_counts: Dictionary = {}

	# Count religions
	var provinces: Dictionary = game_state.provinces
	for province_id in provinces:
		var province: Dictionary = provinces[province_id]
		var religion_key: String = _religion_bucket(province.get("religion", 50))
		religion_counts[religion_key] = int(religion_counts.get(religion_key, 0)) + 1

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
		var new_religion = _flip_religion(province.get("religion", 50))
		province["religion"] = new_religion
		report.changes.append({
			"province_id": province_id,
			"old_religion": province.get("religion", 50),
			"new_religion": new_religion
		})
	game_state.provinces = provinces

	return report


func _religion_bucket(rel) -> String:
	if typeof(rel) == TYPE_INT or typeof(rel) == TYPE_FLOAT:
		var v: float = float(rel)
		if v < 40.0:
			return "latin"
		if v > 60.0:
			return "orthodox"
		return "mixed"
	var s: String = str(rel).to_lower()
	if s in ["christian", "latin", "catholic", "rome"]:
		return "latin"
	if s in ["orthodox", "byzantine", "greek"]:
		return "orthodox"
	if s == "pagan":
		return "pagan"
	return "mixed"


func _flip_religion(rel):
	# jemné posuny na 0-100 osi; legacy string toggle
	if typeof(rel) == TYPE_INT or typeof(rel) == TYPE_FLOAT:
		var v: int = int(rel)
		if v < 50:
			return mini(100, v + 10)
		return maxi(0, v - 10)
	var s: String = str(rel).to_lower()
	if s == "pagan":
		return "christian"
	return "pagan"
