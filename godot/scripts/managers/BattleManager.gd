# scripts/managers/BattleManager.gd
class_name BattleManager
extends RefCounted

## 3-phase battle engine port (Phase 2 React spec).
## Phases: attack → counterattack → decision (+ rout checks).

const Formulas := preload("res://scripts/battle/BattleFormulas.gd")
const C := preload("res://scripts/battle/BattleConfig.gd")

var game_state
var rng: RandomNumberGenerator


func _init(state, rng_ref: RandomNumberGenerator) -> void:
	game_state = state
	rng = rng_ref


func make_army(
	id: String,
	faction_id: String,
	size: int,
	morale: float,
	composition: Dictionary,
	commander_skill: int = 5,
	commander_name: String = "Veliteľ"
) -> Dictionary:
	return {
		"id": id,
		"faction_id": faction_id,
		"size": size,
		"morale": morale,
		"composition": composition,
		"commander": {"id": id + "_cmd", "name": commander_name, "skill": commander_skill}
	}


func _default_ai_action(army: Dictionary, phase: String) -> String:
	var comp: Dictionary = army.get("composition", {})
	var cav: float = float(comp.get("cavalry", 0.0))
	var arc: float = float(comp.get("archers", 0.0))
	if phase == "attack":
		if cav >= 0.4:
			return "flank"
		if arc >= 0.35:
			return "ranged"
		return "melee"
	if phase == "counterattack":
		if float(army.get("morale", 50)) < 35.0:
			return "retreat"
		return "melee" if cav < 0.35 else "flank"
	# decision
	return "melee"


func _apply_losses(army: Dictionary, losses: int) -> void:
	army["size"] = maxi(0, int(army.get("size", 0)) - losses)


func _apply_morale(army: Dictionary, delta: int) -> void:
	army["morale"] = clampf(float(army.get("morale", 50)) + float(delta), 0.0, 100.0)


## Full auto-resolve of a battle (all 3 phases or until rout/retreat).
func auto_resolve(
	attacker: Dictionary,
	defender: Dictionary,
	terrain: String = "field",
	attacker_actions: Array = [],
	defender_actions: Array = []
) -> Dictionary:
	var atk: Dictionary = attacker.duplicate(true)
	var def: Dictionary = defender.duplicate(true)
	var logs: Array = []

	var morale0: Dictionary = Formulas.apply_terrain_morale(atk, def, terrain)
	atk["morale"] = morale0["attacker_morale"]
	def["morale"] = morale0["defender_morale"]

	var result := ""
	var winner_side := ""

	# Phase 1: attack
	var a1: String = str(attacker_actions[0]) if attacker_actions.size() > 0 else _default_ai_action(atk, "attack")
	var d1: String = str(defender_actions[0]) if defender_actions.size() > 0 else _default_ai_action(def, "attack")
	if a1 == "retreat":
		return _finish_retreat(atk, def, logs, "attacker")
	if d1 == "retreat":
		return _finish_retreat(atk, def, logs, "defender")

	var p1: Dictionary = Formulas.evaluate_phase(atk, def, "attack", a1, d1, terrain, rng)
	_apply_losses(atk, int(p1["attacker_losses"]))
	_apply_losses(def, int(p1["defender_losses"]))
	_apply_morale(atk, int(p1["attacker_morale_change"]))
	_apply_morale(def, int(p1["defender_morale_change"]))
	logs.append(_log("attack", a1, d1, p1, atk, def))

	if Formulas.check_rout(float(def["morale"])):
		return _finish_rout(atk, def, logs, "defender")
	if Formulas.check_rout(float(atk["morale"])):
		return _finish_rout(atk, def, logs, "attacker")
	if int(atk["size"]) <= 0:
		return _finish_wipe(atk, def, logs, "defender")
	if int(def["size"]) <= 0:
		return _finish_wipe(atk, def, logs, "attacker")

	# Phase 2: counterattack
	var a2: String = str(attacker_actions[1]) if attacker_actions.size() > 1 else _default_ai_action(atk, "counterattack")
	var d2: String = str(defender_actions[1]) if defender_actions.size() > 1 else _default_ai_action(def, "counterattack")
	if a2 == "retreat":
		return _finish_retreat(atk, def, logs, "attacker")
	if d2 == "retreat":
		return _finish_retreat(atk, def, logs, "defender")

	var p2: Dictionary = Formulas.evaluate_phase(atk, def, "counterattack", a2, d2, terrain, rng)
	_apply_losses(atk, int(p2["attacker_losses"]))
	_apply_losses(def, int(p2["defender_losses"]))
	_apply_morale(atk, int(p2["attacker_morale_change"]))
	_apply_morale(def, int(p2["defender_morale_change"]))
	logs.append(_log("counterattack", a2, d2, p2, atk, def))

	if Formulas.check_rout(float(def["morale"])):
		return _finish_rout(atk, def, logs, "defender")
	if Formulas.check_rout(float(atk["morale"])):
		return _finish_rout(atk, def, logs, "attacker")
	if int(atk["size"]) <= 0:
		return _finish_wipe(atk, def, logs, "defender")
	if int(def["size"]) <= 0:
		return _finish_wipe(atk, def, logs, "attacker")

	# Phase 3: decision
	var a3: String = str(attacker_actions[2]) if attacker_actions.size() > 2 else _default_ai_action(atk, "decision")
	var d3: String = str(defender_actions[2]) if defender_actions.size() > 2 else _default_ai_action(def, "decision")
	if a3 == "retreat":
		return _finish_retreat(atk, def, logs, "attacker")
	if d3 == "retreat":
		return _finish_retreat(atk, def, logs, "defender")

	var dec: Dictionary = Formulas.evaluate_decision_phase(atk, def, a3, d3, terrain, rng)
	winner_side = str(dec["winner"])
	if winner_side == "attacker":
		_apply_losses(def, int(round(int(def["size"]) * C.DECISION_LOSER_LOSSES)))
		_apply_morale(def, C.DECISION_LOSER_MORALE)
		_apply_morale(atk, C.DECISION_WINNER_MORALE)
		result = "victory_decision"
	else:
		_apply_losses(atk, int(round(int(atk["size"]) * C.DECISION_LOSER_LOSSES)))
		_apply_morale(atk, C.DECISION_LOSER_MORALE)
		_apply_morale(def, C.DECISION_WINNER_MORALE)
		result = "victory_decision"

	logs.append({
		"phase": "decision",
		"attacker_action": a3,
		"defender_action": d3,
		"winner": winner_side,
		"ratio": dec["ratio"],
		"attacker_size": atk["size"],
		"defender_size": def["size"],
		"attacker_morale": atk["morale"],
		"defender_morale": def["morale"]
	})

	return {
		"result": result,
		"winner": winner_side,
		"attacker": atk,
		"defender": def,
		"terrain": terrain,
		"phase_logs": logs,
		"is_auto_resolved": true
	}


func _log(phase: String, a_act: String, d_act: String, pr: Dictionary, atk: Dictionary, def: Dictionary) -> Dictionary:
	return {
		"phase": phase,
		"attacker_action": a_act,
		"defender_action": d_act,
		"attacker_losses": pr["attacker_losses"],
		"defender_losses": pr["defender_losses"],
		"attacker_morale_change": pr["attacker_morale_change"],
		"defender_morale_change": pr["defender_morale_change"],
		"ratio": pr["ratio"],
		"attacker_size": atk["size"],
		"defender_size": def["size"],
		"attacker_morale": atk["morale"],
		"defender_morale": def["morale"]
	}


func _finish_rout(atk: Dictionary, def: Dictionary, logs: Array, routed_side: String) -> Dictionary:
	var winner := "attacker" if routed_side == "defender" else "defender"
	var routed: Dictionary = def if routed_side == "defender" else atk
	var extra: int = int(round(int(routed["size"]) * C.ROUT_EXTRA_PURSUE))
	_apply_losses(routed, extra)
	logs.append({"phase": "rout", "routed": routed_side, "extra_losses": extra})
	return {
		"result": "victory_rout",
		"winner": winner,
		"attacker": atk,
		"defender": def,
		"phase_logs": logs,
		"is_auto_resolved": true
	}


func _finish_retreat(atk: Dictionary, def: Dictionary, logs: Array, retreating: String) -> Dictionary:
	var ret: Dictionary = atk if retreating == "attacker" else def
	var loss: int = int(round(int(ret["size"]) * C.RETREAT_LOSSES))
	_apply_losses(ret, loss)
	_apply_morale(ret, -C.RETREAT_MORALE_PENALTY)
	logs.append({"phase": "retreat", "side": retreating, "losses": loss})
	var winner := "defender" if retreating == "attacker" else "attacker"
	return {
		"result": "retreat",
		"winner": winner,
		"attacker": atk,
		"defender": def,
		"phase_logs": logs,
		"is_auto_resolved": true
	}


func _finish_wipe(atk: Dictionary, def: Dictionary, logs: Array, winner: String) -> Dictionary:
	logs.append({"phase": "wipe", "winner": winner})
	return {
		"result": "victory_decision",
		"winner": winner,
		"attacker": atk,
		"defender": def,
		"phase_logs": logs,
		"is_auto_resolved": true
	}


## Convenience: Moravian defense vs Magyar raid on a province (e.g. Devín-like).
func resolve_border_skirmish(province_id: String, terrain: String = "field") -> Dictionary:
	var moravian := make_army(
		"mor_army", "moravia", 800, 70.0,
		{"infantry": 0.55, "cavalry": 0.20, "archers": 0.25},
		6, "Mojmírov veliteľ"
	)
	var magyar := make_army(
		"mag_army", "madari", 900, 75.0,
		{"infantry": 0.25, "cavalry": 0.55, "archers": 0.20},
		5, "Maďarský vojvoda"
	)
	var outcome: Dictionary = auto_resolve(magyar, moravian, terrain)
	outcome["province_id"] = province_id
	# Apply occupation if attackers (magyar) win
	if outcome.get("winner", "") == "attacker" and game_state != null:
		var p = game_state.provinces.get(province_id)
		if p != null and typeof(p) == TYPE_DICTIONARY:
			p["occupier_faction"] = "madari"
			outcome["occupation_applied"] = true
	elif outcome.get("winner", "") == "defender":
		outcome["occupation_applied"] = false
	return outcome
