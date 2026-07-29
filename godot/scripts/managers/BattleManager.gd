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
	var es_ratio: float = attacker_es / defender_es if winner == "attacker" else defender_es / attacker_es

	if es_ratio >= 2.0:
		return "decisive_victory"
	elif es_ratio >= 1.5:
		return "major_victory"
	elif es_ratio >= 1.2:
		return "victory"
	elif es_ratio >= 0.8:
		return "stalemate"
	elif es_ratio >= 0.5:
		return "narrow_victory"
	else:
		return "heroic_victory"


# ─── Phased battle (M8.3) ───

func begin_phased_battle(attacker: Dictionary, defender: Dictionary, terrain: String = "field") -> Dictionary:
	var morale := Formulas.apply_terrain_morale(attacker, defender, terrain)
	var atk := attacker.duplicate(true)
	var def := defender.duplicate(true)
	atk["morale"] = morale["attacker_morale"]
	def["morale"] = morale["defender_morale"]
	return {
		"attacker": atk,
		"defender": def,
		"terrain": terrain,
		"phase_logs": [],
		"routed": ""  # "attacker" | "defender" | ""
	}


func resolve_phase_round(battle: Dictionary, phase: String, attacker_action: String, defender_action: String) -> Dictionary:
	var atk: Dictionary = battle["attacker"]
	var def: Dictionary = battle["defender"]
	var log: Dictionary = Formulas.evaluate_phase(atk, def, phase, attacker_action, defender_action, battle["terrain"], rng)
	atk["size"] = maxi(0, int(atk.get("size", 0)) - int(log["attacker_losses"]))
	def["size"] = maxi(0, int(def.get("size", 0)) - int(log["defender_losses"]))
	atk["morale"] = clampf(float(atk.get("morale", 50)) + float(log["attacker_morale_change"]), 0.0, 100.0)
	def["morale"] = clampf(float(def.get("morale", 50)) + float(log["defender_morale_change"]), 0.0, 100.0)
	log["phase"] = phase
	log["attacker_action"] = attacker_action
	log["defender_action"] = defender_action
	battle["attacker"] = atk
	battle["defender"] = def
	var logs: Array = battle["phase_logs"]
	logs.append(log)
	battle["phase_logs"] = logs
	if Formulas.check_rout(atk["morale"]):
		battle["routed"] = "attacker"
	elif Formulas.check_rout(def["morale"]):
		battle["routed"] = "defender"
	return battle


func resolve_decision(battle: Dictionary, attacker_action: String = "melee", defender_action: String = "melee") -> Dictionary:
	var winner: String
	if battle.get("routed", "") != "":
		winner = "defender" if battle["routed"] == "attacker" else "attacker"
	else:
		var dec: Dictionary = Formulas.evaluate_decision_phase(battle["attacker"], battle["defender"], attacker_action, defender_action, battle["terrain"], rng)
		winner = dec["winner"]
		var logs: Array = battle["phase_logs"]
		logs.append({"phase": "decision", "winner": winner})
		battle["phase_logs"] = logs
	battle["winner"] = winner
	battle["result"] = _evaluate_battle_result(winner, Formulas.calculate_effective_strength(battle["attacker"], true, battle["terrain"]), Formulas.calculate_effective_strength(battle["defender"], false, battle["terrain"]))
	return battle


func pick_ai_action(army: Dictionary) -> String:
	var comp: Dictionary = army.get("composition", {})
	var cav: float = float(comp.get("cavalry", 0.0))
	var arc: float = float(comp.get("archers", 0.0))
	if float(army.get("morale", 50.0)) <= C.ROUT_THRESHOLD + 10:
		return "retreat"
	if cav >= arc and cav >= float(comp.get("infantry", 0.0)):
		return "flank"
	if arc > cav and arc > float(comp.get("infantry", 0.0)):
		return "ranged"
	return "melee"