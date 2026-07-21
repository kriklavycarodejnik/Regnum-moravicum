# scripts/managers/SuccessionManager.gd
class_name SuccessionManager
extends RefCounted

## M4 skeleton — succession rules (seniority, primogeniture, election).
## Full port from React successionEngine later.

var game_state
var rng: RandomNumberGenerator

# Succession types
const SUCCESSION_TYPES := {
	"seniority": "Seniority (oldest living male)",
	"primogeniture": "Primogeniture (firstborn son)",
	"election": "Election (nobles vote)"
}

# Current succession type (default: seniority)
var current_type: String = "seniority"


func _init(state, rng_ref: RandomNumberGenerator) -> void:
	game_state = state
	rng = rng_ref


func set_succession_type(new_type: String) -> bool:
	if SUCCESSION_TYPES.has(new_type):
		current_type = new_type
		return true
	return false


func get_heir() -> Dictionary:
	var ruler: Dictionary = _get_current_ruler()
	if ruler == null:
		return {}

	match current_type:
		"seniority":
			return _find_senior_heir(ruler)
		"primogeniture":
			return _find_primogeniture_heir(ruler)
		"election":
			return _elect_heir(ruler)
		_:
			return {}


func _get_current_ruler() -> Dictionary:
	for noble_id in game_state.nobles:
		var noble: Dictionary = game_state.nobles[noble_id]
		if typeof(noble) == TYPE_DICTIONARY and noble.get("is_ruler", false):
			return noble
	return {}


func _find_senior_heir(ruler: Dictionary) -> Dictionary:
	var dynasty_id: String = str(ruler.get("dynasty_id", ""))
	var candidates: Array = []
	for noble_id in game_state.nobles:
		var noble: Dictionary = game_state.nobles[noble_id]
		if typeof(noble) == TYPE_DICTIONARY and str(noble.get("dynasty_id", "")) == dynasty_id and not noble.get("is_ruler", false):
			candidates.append(noble)

	if candidates.is_empty():
		return {}

	# Sort by age (descending)
	candidates.sort_custom(_sort_by_age_desc)
	return candidates[0]


func _find_primogeniture_heir(ruler: Dictionary) -> Dictionary:
	var dynasty_id: String = str(ruler.get("dynasty_id", ""))
	var candidates: Array = []
	for noble_id in game_state.nobles:
		var noble: Dictionary = game_state.nobles[noble_id]
		if typeof(noble) == TYPE_DICTIONARY and str(noble.get("dynasty_id", "")) == dynasty_id and not noble.get("is_ruler", false):
			candidates.append(noble)

	if candidates.is_empty():
		return {}

	# Sort by birth_year (ascending = oldest first)
	candidates.sort_custom(_sort_by_birth_year_asc)
	return candidates[0]


func _elect_heir(ruler: Dictionary) -> Dictionary:
	var nobles: Array = []
	for noble_id in game_state.nobles:
		var noble: Dictionary = game_state.nobles[noble_id]
		if typeof(noble) == TYPE_DICTIONARY and not noble.get("is_ruler", false):
			nobles.append(noble)

	if nobles.is_empty():
		return {}

	# Simple weighted random (prestige-based)
	var total_prestige: float = 0.0
	for noble in nobles:
		total_prestige += float(noble.get("prestige", 10.0))

	var roll: float = rng.randf_range(0.0, total_prestige)
	var cumulative: float = 0.0
	for noble in nobles:
		cumulative += float(noble.get("prestige", 10.0))
		if roll <= cumulative:
			return noble

	return nobles[-1]


func _sort_by_age_desc(a: Dictionary, b: Dictionary) -> bool:
	var age_a: int = game_state.year - int(a.get("birth_year", 0))
	var age_b: int = game_state.year - int(b.get("birth_year", 0))
	return age_a > age_b


func _sort_by_birth_year_asc(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("birth_year", 0)) < int(b.get("birth_year", 0))


func process_succession() -> Dictionary:
	var ruler: Dictionary = _get_current_ruler()
	if ruler == null:
		return {"type": "succession", "error": "no_ruler"}

	var heir: Dictionary = get_heir()
	if heir.is_empty():
		return {
			"type": "succession",
			"event": "no_heir",
			"ruler": ruler.get("name", ""),
			"dynasty": ruler.get("dynasty_id", "")
		}

	# Apply succession
	ruler["is_ruler"] = false
	heir["is_ruler"] = true

	return {
		"type": "succession",
		"old_ruler": ruler.get("name", ""),
		"new_ruler": heir.get("name", ""),
		"succession_type": current_type,
		"dynasty": heir.get("dynasty_id", "")
	}