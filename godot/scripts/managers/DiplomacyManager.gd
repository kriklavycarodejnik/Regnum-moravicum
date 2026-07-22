# scripts/managers/DiplomacyManager.gd
class_name DiplomacyManager
extends RefCounted

var game_state
var rng: RandomNumberGenerator


func _init(state: RefCounted = null, rng_ref: RandomNumberGenerator = null) -> void:
	if state != null:
		game_state = state
	if rng_ref != null:
		rng = rng_ref
	if game_state != null:
		_ensure_default_factions()


func _ensure_default_factions() -> void:
	if typeof(game_state.factions) != TYPE_DICTIONARY:
		game_state.factions = {}
	var default_factions: Dictionary = {
		"moravia": {"name": "Veľká Morava", "mood": 100.0, "relations": {}},
		"franks": {"name": "Franská ríša", "mood": 50.0, "relations": {}},
		"bavaria": {"name": "Bavorsko", "mood": 40.0, "relations": {}},
		"hungary": {"name": "Maďari", "mood": 20.0, "relations": {}},
		"poland": {"name": "Poľsko", "mood": 30.0, "relations": {}},
		"bohemia": {"name": "Čechy", "mood": 60.0, "relations": {}},
		"byzantium": {"name": "Byzantská ríša", "mood": 50.0, "relations": {}},
	}
	var factions: Dictionary = game_state.factions
	for faction_id in default_factions:
		if factions.get(faction_id) == null:
			factions[faction_id] = default_factions[faction_id].duplicate(true)
		else:
			var f: Dictionary = factions[faction_id]
			if not f.has("relations"):
				f["relations"] = {}
			if not f.has("mood"):
				f["mood"] = 50.0
			if not f.has("name"):
				f["name"] = str(faction_id)
	game_state.factions = factions


func process_diplomacy() -> Dictionary:
	var report := {"type": "diplomacy", "mood_changes": {}}
	var factions: Dictionary = game_state.factions
	for faction_id in factions:
		if faction_id == "moravia":
			continue
		var mood: float = float(factions[faction_id].get("mood", 50.0))
		var drift := 0.0
		if rng:
			drift = rng.randf_range(-2.0, 2.0)
		# treaties soften drift
		var rel: Dictionary = factions[faction_id].get("relations", {})
		if typeof(rel) == TYPE_DICTIONARY:
			if bool(rel.get("nap", false)):
				drift = maxf(drift, 0.0)
			if bool(rel.get("trade", false)):
				drift += 0.5
			if bool(rel.get("military_pact", false)):
				drift += 0.25
		mood = clampf(mood + drift, 0.0, 100.0)
		factions[faction_id]["mood"] = mood
		report.mood_changes[faction_id] = mood
	game_state.factions = factions
	return report


func list_factions() -> Array:
	_ensure_default_factions()
	var out: Array = []
	for fid in game_state.factions:
		if fid == "moravia":
			continue
		var f: Dictionary = game_state.factions[fid]
		out.append({
			"id": fid,
			"name": str(f.get("name", fid)),
			"mood": float(f.get("mood", 50.0)),
			"relations": f.get("relations", {}).duplicate(true) if typeof(f.get("relations", {})) == TYPE_DICTIONARY else {},
		})
	return out


func get_mood(faction_id: String) -> float:
	_ensure_default_factions()
	var f = game_state.factions.get(faction_id, {})
	if typeof(f) != TYPE_DICTIONARY:
		return 50.0
	return float(f.get("mood", 50.0))


func send_gift(faction_id: String, gold_cost: int = 50) -> Dictionary:
	_ensure_default_factions()
	if faction_id == "moravia" or not game_state.factions.has(faction_id):
		return {"ok": false, "error": "neplatná frakcia"}
	if game_state.has_method("ensure_resources"):
		game_state.ensure_resources()
	var res: Dictionary = game_state.resources
	if int(res.get("gold", 0)) < gold_cost:
		return {"ok": false, "error": "nedostatok zlata"}
	res["gold"] = int(res.get("gold", 0)) - gold_cost
	game_state.resources = res
	var fv2 = game_state.factions[faction_id]
	if typeof(fv2) != TYPE_DICTIONARY:
		return {"ok": false, "error": "poškodená frakcia"}
	var f: Dictionary = fv2
	f["mood"] = clampf(float(f.get("mood", 50.0)) + 10.0, 0.0, 100.0)
	game_state.factions[faction_id] = f
	return {"ok": true, "mood": f["mood"], "chronicle": "Dar pre %s (−%d zlata, nálada +10)." % [str(f.get("name", faction_id)), gold_cost]}


func threaten(faction_id: String) -> Dictionary:
	_ensure_default_factions()
	if faction_id == "moravia" or not game_state.factions.has(faction_id):
		return {"ok": false, "error": "neplatná frakcia"}
	var fv3 = game_state.factions[faction_id]
	if typeof(fv3) != TYPE_DICTIONARY:
		return {"ok": false, "error": "poškodená frakcia"}
	var f: Dictionary = fv3
	var delta: float = -8.0
	if rng and rng.randf() < 0.3:
		delta = -3.0  # občas menej efektívne
	f["mood"] = clampf(float(f.get("mood", 50.0)) + delta, 0.0, 100.0)
	var prestige_gain := 2
	if game_state.has_method("ensure_resources"):
		game_state.ensure_resources()
	var res: Dictionary = game_state.resources
	res["prestige"] = int(res.get("prestige", 0)) + prestige_gain
	game_state.resources = res
	game_state.factions[faction_id] = f
	return {
		"ok": true,
		"mood": f["mood"],
		"chronicle": "Hrozba voči %s (nálada %.0f, prestíž +%d)." % [str(f.get("name", faction_id)), f["mood"], prestige_gain],
	}


func set_treaty(faction_id: String, treaty: String, enabled: bool = true) -> Dictionary:
	_ensure_default_factions()
	if faction_id == "moravia" or not game_state.factions.has(faction_id):
		return {"ok": false, "error": "neplatná frakcia"}
	if treaty not in ["nap", "trade", "military_pact"]:
		return {"ok": false, "error": "neznáma zmluva"}
	var fv = game_state.factions[faction_id]
	if typeof(fv) != TYPE_DICTIONARY:
		return {"ok": false, "error": "poškodená frakcia"}
	var f: Dictionary = fv
	var rel_v = f.get("relations", {})
	var rel: Dictionary = rel_v if typeof(rel_v) == TYPE_DICTIONARY else {}
	rel[treaty] = enabled
	f["relations"] = rel
	if enabled:
		f["mood"] = clampf(float(f.get("mood", 50.0)) + 6.0, 0.0, 100.0)
	game_state.factions[faction_id] = f
	var labels: Dictionary = {
		"nap": "neútočná zmluva",
		"trade": "obchodná zmluva",
		"military_pact": "vojenský pakt",
	}
	var label: String = str(labels.get(treaty, treaty))
	return {
		"ok": true,
		"mood": f["mood"],
		"relations": rel.duplicate(true),
		"chronicle": "%s s %s: %s." % [label.capitalize(), str(f.get("name", faction_id)), "uzavretá" if enabled else "zrušená"],
	}
