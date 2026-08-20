# scripts/scenarios/HungarianWarScenario.gd
class_name HungarianWarScenario
extends RefCounted

const GAME_STATE := preload("res://scripts/core/GameState.gd")
const C := preload("res://scripts/battle/BattleConfig.gd")
const Formulas := preload("res://scripts/battle/BattleFormulas.gd")

var game_state
var war_manager
var battle_manager
var rng: RandomNumberGenerator


func _init(
	state: RefCounted = null,
	war_mgr = null,
	battle_mgr = null,
	rng_ref: RandomNumberGenerator = null
) -> void:
	if state != null:
		game_state = state
	if war_mgr != null:
		war_manager = war_mgr
	if battle_mgr != null:
		battle_manager = battle_mgr
	if rng_ref != null:
		rng = rng_ref


const PROVINCE_DEVIN := "devin"
const TERRAIN_DEVIN := "river"
const HUNGARIAN_MAIN_ARMY_SIZE := 12000
const MORAVIAN_MAIN_ARMY_SIZE := 8000
const HUNGARIAN_REINFORCEMENTS_SIZE := 3000
const MORAVIAN_REINFORCEMENTS_SIZE := 2000


func create_initial_armies() -> Dictionary:
	var hungarian_main: Dictionary = {
		"faction_id": "hungary",
		"size": HUNGARIAN_MAIN_ARMY_SIZE,
		"morale": 85.0,
		"composition": {"infantry": 0.4, "cavalry": 0.5, "archers": 0.1},
		"commander": {"skill": 8}
	}
	var moravian_main: Dictionary = {
		"faction_id": "moravia",
		"size": MORAVIAN_MAIN_ARMY_SIZE,
		"morale": 90.0,
		"composition": {"infantry": 0.6, "cavalry": 0.2, "archers": 0.2},
		"commander": {"skill": 9}
	}
	var hungarian_reinforcements: Dictionary = {
		"faction_id": "hungary",
		"size": HUNGARIAN_REINFORCEMENTS_SIZE,
		"morale": 70.0,
		"composition": {"infantry": 0.5, "cavalry": 0.4, "archers": 0.1},
		"commander": {"skill": 6}
	}
	var moravian_reinforcements: Dictionary = {
		"faction_id": "moravia",
		"size": MORAVIAN_REINFORCEMENTS_SIZE,
		"morale": 75.0,
		"composition": {"infantry": 0.7, "cavalry": 0.2, "archers": 0.1},
		"commander": {"skill": 7}
	}

	return {
		"hungarian_main": hungarian_main,
		"moravian_main": moravian_main,
		"hungarian_reinforcements": hungarian_reinforcements,
		"moravian_reinforcements": moravian_reinforcements
	}


func resolve_devine_battle() -> Dictionary:
	# Defense-in-depth: guard against Nil game_state (uninitialised scenario)
	if game_state == null:
		return {"ok": false, "error": "no_state", "chronicle": "Chyba: herný stav nie je inicializovaný."}
	# P-1.1 guard — Devín max 1× za run. Guard sa kontroluje v samotnom scenári,
	# lebo každý call site (WarManager.process_wars, WarManager.resolve_devine_battle,
	# manuálne tlačidlo) nakoniec volá túto metódu.
	if game_state.devine_resolved:
		return {"ok": false, "error": "already_resolved", "chronicle": "Scenár Devín 907 už bol odohraný."}
	# Defense-in-depth pre-907 guard: bitka je uzamknutá pred júlom 907
	var y: int = game_state.year
	var m: int = game_state.month
	if y < 907 or (y == 907 and m < 7):
		return {"ok": false, "error": "too_early", "chronicle": "Devín 907 ešte nenastal."}
	var armies: Dictionary = create_initial_armies()
	var hungarian: Dictionary = armies["hungarian_main"].duplicate(true)
	var moravian: Dictionary = armies["moravian_main"].duplicate(true)

	# Apply terrain modifiers (river)
	var tm: Dictionary = C.TERRAIN_MODIFIERS.get(TERRAIN_DEVIN, C.TERRAIN_MODIFIERS["field"])
	hungarian["morale"] = clampf(float(hungarian["morale"]) + float(tm["attackerMorale"]) + C.HUNGARIAN_RIVER_MORALE, 0.0, 100.0)
	moravian["morale"] = clampf(float(moravian["morale"]) + float(tm["defenderMorale"]), 0.0, 100.0)

	# Apply Greek fire bonus (defender morale ×1.15)
	moravian["morale"] = clampf(float(moravian["morale"]) * 1.15, 0.0, 100.0)

	# Auto-resolve
	var outcome: Dictionary = battle_manager.auto_resolve(hungarian, moravian, TERRAIN_DEVIN)

	# Canon invariant (NAVRH §4.1): Devín 907 winner == "attacker" (Maďari)
	outcome["winner"] = "attacker"
	outcome["result"] = battle_manager._evaluate_battle_result("attacker", outcome.get("attacker_es", 0.0), outcome.get("defender_es", 0.0))

	# Apply consequences BEFORE setting devine_resolved (reviewer item #3)
	_apply_devine_consequences()
	game_state.devine_resolved = true

	outcome["ok"] = true
	outcome["chronicle"] = "907 · Devín padol: maďarské vojská prelomili riečnu obranu. Prestíž -30, lojalita Devína -20, nálada Maďarov +30."
	return outcome


# P-1.1 — mechanické dôsledky Devín 907 (canon NAVRH §4.1):
# prestíž -30, lojalita Devína -20, mood frakcie Maďarov +30, kronika kapitola.
func _apply_devine_consequences() -> void:
	var resources: Dictionary = game_state.resources
	resources["prestige"] = maxi(0, int(resources.get("prestige", 0)) - 30)
	game_state.resources = resources

	var provinces: Dictionary = game_state.provinces
	if provinces.has(PROVINCE_DEVIN):
		var province: Dictionary = provinces[PROVINCE_DEVIN]
		province["loyalty"] = clampf(float(province.get("loyalty", 50)) - 20.0, 0.0, 100.0)
		provinces[PROVINCE_DEVIN] = province
	game_state.provinces = provinces

	var factions: Dictionary = game_state.factions
	if factions.has("hungary"):
		var hungary: Dictionary = factions["hungary"]
		hungary["mood"] = clampf(float(hungary.get("mood", 20.0)) + 30.0, 0.0, 100.0)
		factions["hungary"] = hungary
	game_state.factions = factions

	var chronicle: Array = game_state.chronicle
	chronicle.append({
		"year": 907,
		"month": 7,
		"text": "907 · Devín padol: maďarské vojská prelomili riečnu obranu. Prestíž -30, lojalita Devína -20, nálada Maďarov +30."
	})
	game_state.chronicle = chronicle