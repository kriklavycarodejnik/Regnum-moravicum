# scripts/managers/BattleManager.gd
class_name BattleManager
extends RefCounted

const _GameState := preload("res://scripts/core/GameState.gd")
const C := preload("res://scripts/battle/BattleConfig.gd")
const Formulas := preload("res://scripts/battle/BattleFormulas.gd")

var game_state
var rng: RandomNumberGenerator


func _init(state: RefCounted = null, rng_ref: RandomNumberGenerator = null) -> void:
	if state != null:
		game_state = state
	if rng_ref != null:
		rng = rng_ref


func auto_resolve(attacker: Dictionary, defender: Dictionary, terrain: String = "field") -> Dictionary:
	var attacker_es: float = Formulas.calculate_effective_strength(attacker, true, terrain)
	var defender_es: float = Formulas.calculate_effective_strength(defender, false, terrain)
	var total_es: float = attacker_es + defender_es
	var attacker_win_chance: float = attacker_es / total_es

	var winner: String = "attacker" if rng.randf_range(0.0, 1.0) <= attacker_win_chance else "defender"
	var result: String = _evaluate_battle_result(winner, attacker_es, defender_es)

	return {
		"winner": winner,
		"result": result,
		"attacker_es": attacker_es,
		"defender_es": defender_es,
		"terrain": terrain
	}


func _evaluate_battle_result(winner: String, attacker_es: float, defender_es: float) -> String:
	var es_ratio: float = attacker_es / defender_es if winner == "defender" else defender_es / attacker_es

	if es_ratio >= 2.0:
		return "decisive_victory"
	elif es_ratio >= 1.5:
		return "major_victory"
	elif es_ratio >= 1.2:
		return "victory"
	elif es_ratio >= 0.8:
		return "stalemate"
	elif es_ratio >= 0.5:
		return "minor_defeat"
	else:
		return "decisive_defeat"