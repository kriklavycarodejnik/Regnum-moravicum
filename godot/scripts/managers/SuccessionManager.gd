# scripts/managers/SuccessionManager.gd
class_name SuccessionManager
extends RefCounted

const GAME_STATE := preload("res://scripts/core/GameState.gd")

var game_state
var rng: RandomNumberGenerator


func _init(state: RefCounted = null, rng_ref: RandomNumberGenerator = null) -> void:
	if state != null:
		game_state = state
	if rng_ref != null:
		rng = rng_ref


func process_succession() -> Dictionary:
	var report := {"type": "succession", "new_ruler": null, "heir": null}
	var ruler: Dictionary = _get_current_ruler()
	var heir: Dictionary = get_heir()

	if ruler.is_empty() or ruler.get("is_ruler", false) == false:
		# No ruler — elect new one
		var new_ruler: Dictionary = _elect_new_ruler()
		if not new_ruler.is_empty():
			report.new_ruler = new_ruler

	report.heir = heir
	return report


func _get_current_ruler() -> Dictionary:
	var nobles: Dictionary = game_state.get("nobles") or {}
	for noble_id in nobles:
		var noble: Dictionary = nobles[noble_id]
		if noble.get("is_ruler", false):
			return noble
	return {}


func get_heir() -> Dictionary:
	var ruler: Dictionary = _get_current_ruler()
	if ruler.is_empty():
		return {}

	var dynasty_id: String = str(ruler.get("dynasty_id", ""))
	var nobles: Dictionary = game_state.get("nobles") or {}
	var candidates: Array = []
	for noble_id in nobles:
		var noble: Dictionary = nobles[noble_id]
		if str(noble.get("dynasty_id", "")) == dynasty_id and not noble.get("is_ruler", false):
			candidates.append(noble)

	if candidates.is_empty():
		return {}

	# Seniority: oldest candidate
	var current_year: int = game_state.get("year") or 902
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var age_a: int = current_year - int(a.get("birth_year", 850))
		var age_b: int = current_year - int(b.get("birth_year", 850))
		return age_a > age_b
	)
	return candidates[0]


func _elect_new_ruler() -> Dictionary:
	var nobles: Dictionary = game_state.get("nobles") or {}
	var candidates: Array = []
	for noble_id in nobles:
		var noble: Dictionary = nobles[noble_id]
		if not noble.get("is_ruler", false):
			candidates.append(noble)

	if candidates.is_empty():
		return {}

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("prestige", 0)) > int(b.get("prestige", 0))
	)
	var new_ruler: Dictionary = candidates[0]
	new_ruler["is_ruler"] = true
	
	# Update nobles
	nobles[new_ruler.id] = new_ruler
	game_state.set("nobles", nobles)
	
	return new_ruler