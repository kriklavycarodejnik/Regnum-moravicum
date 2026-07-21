# scripts/battle/BattleFormulas.gd
class_name BattleFormulas
extends RefCounted

## Port of src/battle/formulas.ts (Phase 2 spec). Pure functions + seeded RNG.

const C := preload("res://scripts/battle/BattleConfig.gd")


static func clampf_ratio(value: float, lo: float, hi: float) -> float:
	return clampf(value, lo, hi)


static func composition_factor(composition: Dictionary, terrain: String, faction_id: String) -> float:
	var factor := 0.0
	for unit_type in composition:
		var ratio: float = float(composition[unit_type])
		var mult: float = float(C.UNIT_TERRAIN.get(unit_type, {}).get(terrain, 1.0))
		# Hungarian cavalry on field
		if faction_id in ["hungarian", "madari"] and unit_type == "cavalry" and terrain == "field":
			mult = C.HUNGARIAN_CAVALRY_FIELD
		factor += ratio * mult
	if factor <= 0.0:
		factor = 1.0
	return factor


static func calculate_effective_strength(
	army: Dictionary,
	is_attacker: bool,
	terrain: String
) -> float:
	var size: float = float(army.get("size", 0))
	var morale: float = float(army.get("morale", 50))
	var skill: float = float(army.get("commander", {}).get("skill", 5))
	var faction_id: String = str(army.get("faction_id", army.get("factionId", "")))
	var composition: Dictionary = army.get("composition", {
		"infantry": 0.5, "cavalry": 0.3, "archers": 0.2
	})

	var tm: Dictionary = C.TERRAIN_MODIFIERS.get(terrain, C.TERRAIN_MODIFIERS["field"])
	var terrain_bonus: float = float(tm["attackBonus"] if is_attacker else tm["defenseBonus"])

	# Moravian fortress defense
	if faction_id in ["moravian", "moravia"] and terrain == "fortress" and not is_attacker:
		terrain_bonus *= C.MORAVIAN_FORTRESS_DEF

	var comp := composition_factor(composition, terrain, faction_id)
	var es: float = size * (morale / 100.0) * (1.0 + terrain_bonus) * comp
	es *= (1.0 + skill * C.COMMANDER_STRENGTH_PER_SKILL)
	return maxf(0.0, es)


static func get_action_modifier(my_action: String, enemy_action: String) -> float:
	return float(C.ACTION_COUNTER.get(my_action, {}).get(enemy_action, 1.0))


static func evaluate_phase(
	attacker: Dictionary,
	defender: Dictionary,
	phase: String,
	attacker_action: String,
	defender_action: String,
	terrain: String,
	rng: RandomNumberGenerator
) -> Dictionary:
	var es_a := calculate_effective_strength(attacker, true, terrain)
	var es_d := calculate_effective_strength(defender, false, terrain)
	var mod_a := get_action_modifier(attacker_action, defender_action)
	var mod_d := get_action_modifier(defender_action, attacker_action)

	var rng_a := rng.randf_range(C.RNG_PHASE.x, C.RNG_PHASE.y)
	var rng_d := rng.randf_range(C.RNG_PHASE.x, C.RNG_PHASE.y)

	var power_a := es_a * mod_a * rng_a
	var power_d := es_d * mod_d * rng_d
	if power_d <= 0.0:
		power_d = 0.001
	var ratio := power_a / power_d

	var base_loss: float = float(C.BASE_LOSS_RATE.get(phase, 0.06))
	var clamped_r := clampf_ratio(ratio, C.LOSS_RATIO_CLAMP.x, C.LOSS_RATIO_CLAMP.y)
	var clamped_inv := clampf_ratio(1.0 / ratio if ratio > 0.0 else 2.0, C.LOSS_RATIO_CLAMP.x, C.LOSS_RATIO_CLAMP.y)

	var def_size: int = int(defender.get("size", 0))
	var atk_size: int = int(attacker.get("size", 0))
	var defender_losses: int = int(round(def_size * base_loss * clamped_r))
	var attacker_losses: int = int(round(atk_size * base_loss * clamped_inv))

	var atk_morale_chg := 0
	var def_morale_chg := 0
	var def_skill: float = float(defender.get("commander", {}).get("skill", 5))
	var atk_skill: float = float(attacker.get("commander", {}).get("skill", 5))

	if ratio > 1.1:
		atk_morale_chg = C.MORALE_WIN_BONUS
		def_morale_chg = -int(round(
			C.MORALE_LOSS_BASE * minf(ratio, 2.0) * (1.0 - def_skill * C.COMMANDER_MORALE_MITIGATION)
		))
	elif ratio < 0.9:
		def_morale_chg = C.MORALE_WIN_BONUS
		atk_morale_chg = -int(round(
			C.MORALE_LOSS_BASE * minf(1.0 / ratio if ratio > 0.0 else 2.0, 2.0) * (1.0 - atk_skill * C.COMMANDER_MORALE_MITIGATION)
		))
	else:
		atk_morale_chg = -C.MORALE_DRAW_PENALTY
		def_morale_chg = -C.MORALE_DRAW_PENALTY

	return {
		"attacker_losses": attacker_losses,
		"defender_losses": defender_losses,
		"attacker_morale_change": atk_morale_chg,
		"defender_morale_change": def_morale_chg,
		"ratio": ratio
	}


static func evaluate_decision_phase(
	attacker: Dictionary,
	defender: Dictionary,
	attacker_action: String,
	defender_action: String,
	terrain: String,
	rng: RandomNumberGenerator
) -> Dictionary:
	var es_a := calculate_effective_strength(attacker, true, terrain)
	var es_d := calculate_effective_strength(defender, false, terrain)
	var mod_a := get_action_modifier(attacker_action, defender_action)
	var mod_d := get_action_modifier(defender_action, attacker_action)
	var rng_a := rng.randf_range(C.RNG_DECISION.x, C.RNG_DECISION.y)
	var rng_d := rng.randf_range(C.RNG_DECISION.x, C.RNG_DECISION.y)

	var atk_morale: float = float(attacker.get("morale", 50))
	var def_morale: float = float(defender.get("morale", 50))
	var power_a := es_a * sqrt(atk_morale / 100.0) * mod_a * rng_a
	var power_d := es_d * sqrt(def_morale / 100.0) * mod_d * rng_d
	var ratio := power_a / power_d if power_d > 0.0 else 999.0
	# Spec §6.7: tie → defender wins
	var winner := "attacker" if power_a > power_d else "defender"
	return {"winner": winner, "ratio": ratio}


static func apply_terrain_morale(attacker: Dictionary, defender: Dictionary, terrain: String) -> Dictionary:
	var tm: Dictionary = C.TERRAIN_MODIFIERS.get(terrain, C.TERRAIN_MODIFIERS["field"])
	var atk_m: float = float(attacker.get("morale", 50)) + float(tm["attackerMorale"])
	var def_m: float = float(defender.get("morale", 50)) + float(tm["defenderMorale"])
	var atk_faction: String = str(attacker.get("faction_id", attacker.get("factionId", "")))
	if atk_faction in ["hungarian", "madari"] and terrain == "river":
		atk_m += C.HUNGARIAN_RIVER_MORALE
	return {
		"attacker_morale": maxf(0.0, atk_m),
		"defender_morale": maxf(0.0, def_m)
	}


static func check_rout(morale: float) -> bool:
	return morale <= C.ROUT_THRESHOLD
