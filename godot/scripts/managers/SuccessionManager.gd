# scripts/managers/SuccessionManager.gd
class_name SuccessionManager
extends RefCounted

const GAME_STATE := preload("res://scripts/core/GameState.gd")

var game_state
var rng: RandomNumberGenerator
# Canon: only seniority or primogeniture. Election is explicitly rejected (ANALYZA_KANONU.md Chyba c.2).
var _succession_type: String = "seniority"


func _init(state: RefCounted = null, rng_ref: RandomNumberGenerator = null) -> void:
	if state != null:
		game_state = state
	if rng_ref != null:
		rng = rng_ref


# --- canon-compliant succession type control (replaces missing set_succession_type) ---

func set_succession_type(type: String) -> bool:
	# ANALYZA_KANONU.md: "Seniorát / primogenitúra (žiadna voľba, žiadne hybridy)"
	# Election is NOT a valid succession type and must be rejected.
	if type == "seniority" or type == "primogeniture":
		_succession_type = type
		return true
	return false


# --- public entry point called by TickManager each month ---

func process_succession() -> Dictionary:
	var report := {
		"type": "succession",
		"old_ruler": null,
		"new_ruler": null,
		"heir": null,
		"event": null
	}
	var ruler: Dictionary = _get_current_ruler()
	var heir: Dictionary = get_heir()

	if ruler.is_empty() or ruler.get("is_ruler", false) == false:
		# No valid ruler on the throne.
		if not heir.is_empty():
			# Canon: transfer rule to the heir within the dynasty (seniority/primogeniture).
			# NOT election — _elect_new_ruler() is removed.
			report.old_ruler = ruler
			_transfer_rule(heir)
			report.new_ruler = heir
			report.heir = heir
		else:
			# Dynasty line is extinct → dynastic crisis / regency.
			# NOT election — no one is elected off-screen.
			report.event = "dynastic_crisis"
			report.heir = {}
		return report

	# Ruler is alive and on the throne — report heir for reference.
	report.old_ruler = ruler
	report.heir = heir
	return report


# --- internal helpers ---

func _transfer_rule(heir: Dictionary) -> void:
	var nobles: Dictionary = game_state.nobles
	# Clear the previous ruler flag on every noble that currently has it
	# (handles the case where the old ruler was already unmarked by an external event).
	for noble_id in nobles:
		if nobles[noble_id].get("is_ruler", false):
			nobles[noble_id]["is_ruler"] = false
	# Promote the heir
	if heir.has("id") and nobles.has(heir.id):
		nobles[heir.id]["is_ruler"] = true
	game_state.nobles = nobles


func _get_current_ruler() -> Dictionary:
	var nobles: Dictionary = game_state.nobles
	for noble_id in nobles:
		var noble: Dictionary = nobles[noble_id]
		if noble.get("is_ruler", false):
			return noble
	return {}


# --- heir selection: seniority or primogeniture, male-only, within dynasty ---

func get_heir() -> Dictionary:
	var ruler: Dictionary = _get_current_ruler()
	if ruler.is_empty():
		return {}

	var dynasty_id: String = str(ruler.get("dynasty_id", ""))
	var nobles: Dictionary = game_state.nobles
	var candidates: Array = []
	for noble_id in nobles:
		var noble: Dictionary = nobles[noble_id]
		if str(noble.get("dynasty_id", "")) != dynasty_id:
			continue
		if noble.get("is_ruler", false):
			continue
		# Canon: inheritance is limited to male relatives ("mužský príbuzný").
		# If a "gender" field exists and is not "male", exclude. Absent field → include
		# (backward-compatible with existing data that has no gender key).
		var gender: String = str(noble.get("gender", "male"))
		if gender != "male":
			continue
		candidates.append(noble)

	if candidates.is_empty():
		return {}

	if _succession_type == "seniority":
		# Seniority: oldest living male dynastic relative.
		var current_year: int = game_state.year
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var age_a: int = current_year - int(a.get("birth_year", 850))
			var age_b: int = current_year - int(b.get("birth_year", 850))
			return age_a > age_b
		)
		return candidates[0]

	elif _succession_type == "primogeniture":
		# Primogeniture: firstborn-line heir. In the absence of parent/child data,
		# prefer candidates of the next generation (born after the ruler), then fall
		# back to the oldest available candidate. This is a documented simplification
		# — proper primogeniture requires genealogical links.
		var ruler_birth: int = int(ruler.get("birth_year", 850))
		var next_gen: Array = []
		var prev_gen: Array = []
		for c in candidates:
			var cb: int = int(c.get("birth_year", 850))
			if cb > ruler_birth:
				next_gen.append(c)
			else:
				prev_gen.append(c)
		if not next_gen.is_empty():
			next_gen.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return int(a.get("birth_year", 850)) < int(b.get("birth_year", 850))
			)
			return next_gen[0]
		else:
			prev_gen.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return int(a.get("birth_year", 850)) < int(b.get("birth_year", 850))
			)
			return prev_gen[0]

	else:
		return {}
