# scripts/managers/EconomyManager.gd
class_name EconomyManager
extends RefCounted

## Placeholder economy — intentionally simple for M2.
## Prestige growth follows React victoryEngine idea: tied to average province loyalty.
## NOT production-final; M3+ will replace with full formulas.

var game_state


func _init(state) -> void:
	game_state = state


func grow_prosperity() -> void:
	for province_id in game_state.provinces:
		var p = game_state.provinces[province_id]
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var loyalty: int = int(p.get("loyalty", 50))
		var prosperity: int = int(p.get("prosperity", 50))
		# Slight growth only if loyalty is decent
		var delta: int = 1 if loyalty >= 50 else 0
		p["prosperity"] = clampi(prosperity + delta, 0, 100)


func add_recruitment_pool() -> void:
	pass


func pay_upkeep() -> void:
	# Placeholder fixed upkeep until armies exist (M3)
	var gold: int = int(game_state.resources.get("gold", 0))
	var upkeep: int = 5
	game_state.resources["gold"] = maxi(0, gold - upkeep)


func grow_prestige() -> void:
	# React parity (simplified): prestige from average loyalty
	var total_loyalty := 0
	var count := 0
	for province_id in game_state.provinces:
		var p = game_state.provinces[province_id]
		if typeof(p) != TYPE_DICTIONARY:
			continue
		total_loyalty += int(p.get("loyalty", 0))
		count += 1
	if count == 0:
		return
	var avg: float = float(total_loyalty) / float(count)
	var gain: int = 0
	if avg >= 70.0:
		gain = 2
	elif avg >= 50.0:
		gain = 1
	# else 0
	var prestige: int = int(game_state.resources.get("prestige", 0))
	game_state.resources["prestige"] = prestige + gain


func process_economy() -> Dictionary:
	var gold_before: int = int(game_state.resources.get("gold", 0))
	var prestige_before: int = int(game_state.resources.get("prestige", 0))

	grow_prosperity()
	add_recruitment_pool()
	pay_upkeep()
	grow_prestige()

	return {
		"type": "economy",
		"gold_change": int(game_state.resources.get("gold", 0)) - gold_before,
		"prestige_change": int(game_state.resources.get("prestige", 0)) - prestige_before,
		"placeholder": true
	}
