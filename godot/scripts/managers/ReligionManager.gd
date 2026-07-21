# scripts/managers/ReligionManager.gd
class_name ReligionManager
extends RefCounted

## M4 skeleton — religion spread, heresy, conversion.
## Full port from React religionEngine later.

var game_state
var rng: RandomNumberGenerator

# Religion types
const RELIGIONS := {
	"pagan": {"name": "Slovanské pohanstvo", "prestige_bonus": 0.0, "loyalty_bonus": 0.0},
	"christian": {"name": "Kresťanstvo (Cyrilometodská misia)", "prestige_bonus": 0.1, "loyalty_bonus": 0.05},
	"orthodox": {"name": "Pravoslávie (Byzantský obrad)", "prestige_bonus": 0.15, "loyalty_bonus": 0.1},
	"catholic": {"name": "Katolíctvo (Nemecká misia)", "prestige_bonus": 0.05, "loyalty_bonus": 0.0}
}

# Current state
var dominant_religion: String = "pagan"
var province_religions: Dictionary = {}


func _init(state, rng_ref: RandomNumberGenerator) -> void:
	game_state = state
	rng = rng_ref
	_init_province_religions()


func _init_province_religions() -> void:
	for province_id in game_state.provinces:
		province_religions[province_id] = "pagan"


func set_religion(province_id: String, religion_id: String) -> bool:
	if not RELIGIONS.has(religion_id) or not game_state.provinces.has(province_id):
		return false
	province_religions[province_id] = religion_id
	return true


func get_religion(province_id: String) -> String:
	return str(province_religions.get(province_id, "pagan"))


func get_dominant_religion() -> String:
	return dominant_religion


func convert_province(province_id: String, target_religion: String) -> Dictionary:
	if not RELIGIONS.has(target_religion) or not game_state.provinces.has(province_id):
		return {"ok": false, "error": "invalid_religion_or_province"}

	var current: String = get_religion(province_id)
	if current == target_religion:
		return {"ok": false, "error": "already_converted"}

	# Simple conversion chance (50% base)
	var chance: float = 0.5
	if target_religion == "christian":
		chance += 0.1  # Cyrilometodská misia bonus
	elif target_religion == "orthodox":
		chance += 0.2  # Byzantský vplyv
	elif target_religion == "catholic":
		chance -= 0.1  # Nemecký tlak

	if rng.randf() <= chance:
		set_religion(province_id, target_religion)
		return {"ok": true, "province": province_id, "religion": target_religion}
	else:
		return {"ok": false, "error": "conversion_failed"}


func process_religion() -> Dictionary:
	# Simple spread: 10% chance per province to convert to dominant religion
	var spread_chance: float = 0.1
	var changes: Array = []

	for province_id in game_state.provinces:
		if rng.randf() <= spread_chance:
			var result: Dictionary = convert_province(province_id, dominant_religion)
			if result.get("ok", false):
				changes.append({
					"province": province_id,
					"religion": result.get("religion", "")
				})

	# Update dominant religion (majority vote)
	var counts: Dictionary = {}
	for religion_id in RELIGIONS:
		counts[religion_id] = 0
	for province_id in province_religions:
		var religion: String = str(province_religions[province_id])
		counts[religion] = int(counts.get(religion, 0)) + 1

	var max_count: int = 0
	for religion_id in counts:
		if int(counts[religion_id]) > max_count:
			max_count = int(counts[religion_id])
			dominant_religion = str(religion_id)

	return {
		"type": "religion",
		"dominant_religion": dominant_religion,
		"changes": changes,
		"province_counts": counts
	}