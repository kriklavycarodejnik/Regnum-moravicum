# scripts/managers/EventManager.gd
class_name EventManager
extends RefCounted

const CATALOG_PATH := "res://data/events_catalog.json"

var game_state
var rng: RandomNumberGenerator
var _catalog: Array = []
var _loaded: bool = false


func _init(state: RefCounted = null, rng_ref: RandomNumberGenerator = null) -> void:
	if state != null:
		game_state = state
	if rng_ref != null:
		rng = rng_ref


func _load_catalog() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(CATALOG_PATH):
		push_warning("EventManager: catalog not found at %s" % CATALOG_PATH)
		return
	var f := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) == TYPE_ARRAY:
		_catalog = data


func process_events() -> Dictionary:
	if not _loaded:
		_load_catalog()

	var pending = game_state.pending_event
	if pending != null and typeof(pending) == TYPE_DICTIONARY:
		return {
			"type": "event",
			"title": pending.get("title", ""),
			"text": pending.get("text", pending.get("body", "")),
			"body": pending.get("text", pending.get("body", "")),
			"art_id": pending.get("art_id", ""),
			"choices": pending.get("choices", {}),
		}

	# 1. Check chain events queued via nextEvent
	var chain_out: Dictionary = _try_chain_event()
	if not chain_out.is_empty():
		return chain_out

	# 2. Check historical (year-scoped) events
	var hist_out: Dictionary = _try_historical_event()
	if not hist_out.is_empty():
		return hist_out

	# 3. Random weighted event
	var rand_out: Dictionary = _try_random_event()
	if not rand_out.is_empty():
		return rand_out

	# 4. Fallback: council event (8% chance)
	if rng != null and rng.randf_range(0.0, 1.0) < 0.08:
		var ce: Dictionary = _build_council_event()
		game_state.pending_event = ce
		return {
			"type": "event",
			"title": ce.get("title", "Rada županov"),
			"text": ce.get("text", ""),
			"body": ce.get("text", ""),
			"art_id": ce.get("art_id", ""),
			"choices": ce.get("choices", {}),
		}

	return {"type": "event", "title": "", "text": "", "body": "", "art_id": "", "choices": []}


func _try_chain_event() -> Dictionary:
	var events_v = game_state.pending_event
	if events_v == null or typeof(events_v) != TYPE_DICTIONARY:
		return {}
	var ev: Dictionary = events_v
	var next_id: String = str(ev.get("next_event", ""))
	if next_id == "":
		return {}
	for cat in _catalog:
		if typeof(cat) != TYPE_DICTIONARY:
			continue
		if str(cat.get("id", "")) == next_id and bool(cat.get("chainOnly", false)):
			game_state.pending_event = cat
			var trig: Array = game_state.triggered_events
			if not trig.has(next_id):
				trig.append(next_id)
			return _event_to_report(cat)
	return {}


func _try_historical_event() -> Dictionary:
	var y: int = game_state.year
	for cat in _catalog:
		if typeof(cat) != TYPE_DICTIONARY:
			continue
		var eid: String = str(cat.get("id", ""))
		var conds = cat.get("conditions", {})
		var req_year: int = int(conds.get("year", 0)) if typeof(conds) == TYPE_DICTIONARY else 0
		if req_year != 0 and y != req_year:
			continue
		if bool(cat.get("once", false)) and game_state.triggered_events.has(eid):
			continue
		if bool(cat.get("chainOnly", false)):
			continue
		game_state.pending_event = cat
		var trig: Array = game_state.triggered_events
		if not trig.has(eid):
			trig.append(eid)
		game_state.triggered_events = trig
		return _event_to_report(cat)
	return {}


func _try_random_event() -> Dictionary:
	if rng == null:
		return {}
	var candidates: Array = []
	var total_weight := 0
	for cat in _catalog:
		if typeof(cat) != TYPE_DICTIONARY:
			continue
		if cat.get("type") != "random" and cat.get("type") != "diplomatic" and cat.get("type") != "military" and cat.get("type") != "religious":
			continue
		if bool(cat.get("chainOnly", false)):
			continue
		var eid: String = str(cat.get("id", ""))
		var conds = cat.get("conditions", {})
		var ymin: int = int(conds.get("yearMin", 0)) if typeof(conds) == TYPE_DICTIONARY else 0
		if ymin > 0 and game_state.year < ymin:
			continue
		var cooldown: int = int(cat.get("cooldownTicks", 0))
		if cooldown > 0:
			var cooldowns: Dictionary = game_state.event_cooldowns
			var last: int = int(cooldowns.get(eid, 0))
			if game_state.year * 12 + game_state.month < last + cooldown:
				continue
		var w: int = int(cat.get("weight", 1))
		if w <= 0:
			continue
		candidates.append(cat)
		total_weight += w
	if candidates.is_empty():
		return {}
	var roll: int = rng.randi_range(1, total_weight)
	var acc := 0
	for cat in candidates:
		acc += int(cat.get("weight", 1))
		if acc >= roll:
			game_state.pending_event = cat
			return _event_to_report(cat)
	return {}


func _event_to_report(cat: Dictionary) -> Dictionary:
	return {
		"type": "event",
		"title": cat.get("title", ""),
		"text": cat.get("body", cat.get("title", "")),
		"body": cat.get("body", cat.get("title", "")),
		"art_id": cat.get("art_id", ""),
		"choices": cat.get("choices", {}),
	}


func resolve_choice(choice_id: String) -> Dictionary:
	var pending = game_state.pending_event
	if pending == null or typeof(pending) != TYPE_DICTIONARY:
		return {"ok": false, "error": "no_pending_event"}
	var choices_v = pending.get("choices", {})
	if typeof(choices_v) != TYPE_DICTIONARY and typeof(choices_v) != TYPE_ARRAY:
		return {"ok": false, "error": "invalid_choices"}
	var choice_dict: Dictionary = {}
	if typeof(choices_v) == TYPE_ARRAY:
		var arr: Array = choices_v
		for item in arr:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			if str(item.get("id", "")) == choice_id:
				choice_dict = item
				break
	else:
		var d: Dictionary = choices_v
		if d.has(choice_id):
			var v = d[choice_id]
			if typeof(v) == TYPE_DICTIONARY:
				choice_dict = v

	if choice_dict.is_empty():
		return {"ok": false, "error": "invalid_choice"}

	var effect_v = choice_dict.get("effect", {})
	var effect: Dictionary = effect_v if typeof(effect_v) == TYPE_DICTIONARY else {}
	var resources: Dictionary = game_state.resources

	# Apply resource effects
	for res_key in ["gold", "food", "wood", "stone", "iron", "prestige"]:
		if effect.has(res_key):
			var cur: int = int(resources.get(res_key, 0))
			resources[res_key] = cur + int(effect[res_key])

	# Handle nextEvent chain
	if choice_dict.has("next_event"):
		var next_id: String = str(choice_dict["next_event"])
		for cat in _catalog:
			if typeof(cat) != TYPE_DICTIONARY:
				continue
			if str(cat.get("id", "")) == next_id:
				game_state.pending_event = cat
				break

	# Apply religion change via ReligionManager if available
	if choice_dict.has("religionChange"):
		var delta: int = int(choice_dict["religionChange"])
		_religion_shift(delta)

	# Update cooldown for the triggered event
	var eid: String = str(pending.get("id", ""))
	if eid != "":
		var cooldowns: Dictionary = game_state.event_cooldowns
		cooldowns[eid] = game_state.year * 12 + game_state.month
		game_state.event_cooldowns = cooldowns

	# If not a chain event, clear pending
	var has_next: bool = choice_dict.has("next_event")
	if not has_next:
		game_state.pending_event = null
	else:
		# For chain events, mark we resolved this choice
		pass

	game_state.resources = resources

	var chronicle: String = str(choice_dict.get("text", ""))
	if chronicle == "":
		chronicle = "Voľba prijatá."

	return {
		"ok": true,
		"effect": effect,
		"chronicle": chronicle,
	}


func _religion_shift(delta: int) -> void:
	# Apply to all provinces or just the axis
	var provs: Dictionary = game_state.provinces
	for pid in provs:
		var p = provs[pid]
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var rel_v = p.get("religion", 50)
		var rel: int = 50
		if typeof(rel_v) == TYPE_INT or typeof(rel_v) == TYPE_FLOAT:
			rel = int(clampf(float(rel_v) + float(delta), 0.0, 100.0))
		p["religion"] = rel
	game_state.provinces = provs


func _build_council_event() -> Dictionary:
	return {
		"id": "council",
		"title": "Rada županov",
		"text": "Rada županov: Ako chcete posilniť ríšu?",
		"body": "Rada županov: Ako chcete posilniť ríšu?",
		"art_id": "moravian_court_interior",
		"choices": {
			"gifts": {
				"id": "gifts",
				"text": "Rozdať dary (500 zlata, +10 prestíž)",
				"effect": {"gold": -500, "prestige": 10},
			},
			"fortify": {
				"id": "fortify",
				"text": "Postaviť opevnenie (300 zlata, +5 prestíž)",
				"effect": {"gold": -300, "prestige": 5},
			},
		},
	}
