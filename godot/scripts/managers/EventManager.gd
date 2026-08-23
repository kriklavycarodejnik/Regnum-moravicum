# scripts/managers/EventManager.gd
class_name EventManager
extends RefCounted

const CATALOG_PATH := "res://data/events_catalog.json"

var game_state
var event_rng: RandomNumberGenerator
var _catalog: Array = []
var _loaded: bool = false


func _init(state: RefCounted = null) -> void:
	if state != null:
		game_state = state
		event_rng = RandomNumberGenerator.new()
		event_rng.seed = game_state.event_rng_seed
		# Only restore explicit state on reload (0 = fresh, let seed determine state)
		if game_state.event_rng_state != 0:
			event_rng.state = game_state.event_rng_state


# Save event RNG state back to game_state after operations
func _sync_rng_state() -> void:
	if game_state == null or event_rng == null:
		return
	game_state.event_rng_state = event_rng.state


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


# ── P2 Condition matcher ────────────────────────────────────────────

# Known condition keys that _evaluate_conditions handles.
# Any other key in conditions triggers a warning AND fails the event.
var _known_condition_keys: Array = [
	"year", "month", "yearMin", "yearMax",
	"moodMin", "moodMax",
	"prestige_min", "prestige_max",
	"province_loyalty",
	"flag", "not_flag",
]


func _has_unknown_conditions(conds: Dictionary) -> bool:
	"""Return true if any key in conds is not in _known_condition_keys."""
	if typeof(conds) != TYPE_DICTIONARY:
		return false
	for key in conds:
		if _known_condition_keys.find(key) < 0:
			push_warning("EventManager: unknown condition '%s' — event will NOT fire" % key)
			return true
	return false


func _evaluate_conditions(conds: Dictionary) -> bool:
	"""Returns true if ALL conditions are satisfied (event should trigger).
	Evaluates: moodMin, moodMax, prestige_min, prestige_max,
	            province_loyalty, flag, not_flag.
	Returns true only when every condition passes; logs warnings on failure.
	"""
	if typeof(conds) != TYPE_DICTIONARY:
		return true
	# Unknown keys → warn + deny (never silently pass).
	if _has_unknown_conditions(conds):
		return false
	var warnings: Array = []

	# --- faction mood gates ---
	if _consume_faction_mood(conds, "moodMin", warnings) == false:
		return false
	if _consume_faction_mood(conds, "moodMax", warnings) == false:
		return false

	# --- prestige gates ---
	for gate in ["prestige_min", "prestige_max"]:
		if conds.has(gate):
			var threshold: float = float(conds[gate])
			var actual: int = int(game_state.resources.get("prestige", 0))
			match gate:
				"prestige_min":
					if actual < threshold:
						warnings.append("prestige=%d < %d required by %s" % [actual, threshold, gate])
						return false
				"prestige_max":
					if actual > threshold:
						warnings.append("prestige=%d > %d required by %s" % [actual, threshold, gate])
						return false

	# --- province loyalty gates (min check) ---
	if conds.has("province_loyalty"):
		var pl_dict: Dictionary = conds["province_loyalty"]
		if typeof(pl_dict) == TYPE_DICTIONARY:
			for prov_id in pl_dict:
				var threshold: float = float(pl_dict[prov_id])
				var prov_data: Dictionary = game_state.provinces.get(prov_id, {})
				if typeof(prov_data) != TYPE_DICTIONARY:
					warnings.append("province '%s' not found in GameState.provinces for loyalty check (%s)" % [prov_id, str(threshold)])
					return false
				var actual_loyalty: float = float(prov_data.get("loyalty", 50))
				if actual_loyalty < threshold:
					warnings.append("%s loyalty=%.1f < %.1f required" % [prov_id, actual_loyalty, threshold])
					return false

	# --- flag gates (exact match on GameState.flags dict) ---
	if conds.has("flag"):
		var fl: Dictionary = conds["flag"]
		if typeof(fl) == TYPE_DICTIONARY:
			for flag_name in fl:
				var expected_val: Variant = fl[flag_name]
				var actual_val: Variant = game_state.flags.get(flag_name)
				if actual_val != expected_val:
					warnings.append("flag '%s'=%s does not match value %s" % [flag_name, str(actual_val), str(expected_val)])
					return false
		else:
			warnings.append("unknown condition 'flag': expected dictionary, got %s" % typeof(fl))
			return false

	# --- not_flag gates (negation: block when flag equals value) ---
	if conds.has("not_flag"):
		var nfl: Dictionary = conds["not_flag"]
		if typeof(nfl) == TYPE_DICTIONARY:
			for flag_name in nfl:
				var negated_val: Variant = nfl[flag_name]
				var actual_val: Variant = game_state.flags.get(flag_name)
				if actual_val == negated_val:
					warnings.append("not_flag '%s'=%s is currently set" % [flag_name, str(actual_val)])
					return false
		else:
			warnings.append("unknown condition 'not_flag': expected dictionary, got %s" % typeof(nfl))
			return false

	# Log collected warnings
	for w in warnings:
		push_warning("EventManager: condition failed — %s" % w)

	return true


func _consume_faction_mood(conds: Dictionary, gate_key: String, warnings: Array) -> bool:
	"""Evaluate moodMin or moodMax gates from conditions dict."""
	if conds.has(gate_key) == false:
		return true
	var gate_dict: Variant = conds[gate_key]
	if typeof(gate_dict) != TYPE_DICTIONARY:
		warnings.append("condition '%s': expected dictionary {faction: threshold}, got %s" % [gate_key, typeof(gate_dict)])
		return false

	for fid in gate_dict:
		var threshold: float = float(gate_dict[fid])
		var actual: float = 50.0  # safe default when game_state.factions is empty
		if game_state and typeof(game_state.factions) == TYPE_DICTIONARY and game_state.factions.has(fid):
			var f = game_state.factions[fid]
			if typeof(f) == TYPE_DICTIONARY:
				actual = float(f.get("mood", 50))
		match gate_key:
			"moodMin":
				if actual < threshold:
					warnings.append("%s.mood=%.1f < moodMin threshold %.1f" % [fid, actual, threshold])
					return false
			"moodMax":
				if actual > threshold:
					warnings.append("%s.mood=%.1f > moodMax threshold %.1f" % [fid, actual, threshold])
					return false
	return true


# ── End P2 condition matcher ────────────────────────────────────────


func process_events() -> Dictionary:
	if not _loaded:
		_load_catalog()

	var pending = game_state.pending_event
	if pending != null and typeof(pending) == TYPE_DICTIONARY:
		return {
			"type": "event",
			"id": str(pending.get("id", "")),
			"title": pending.get("title", ""),
			"text": pending.get("text", pending.get("body", "")),
			"body": pending.get("text", pending.get("body", "")),
			"art_id": pending.get("art_id", ""),
			"choices": pending.get("choices", {}),
		}

	# 1. Check chain events queued via nextEvent
	var chain_out: Dictionary = _try_chain_event()
	if not chain_out.is_empty():
		_sync_rng_state()
		return chain_out

	# 2. Check historical (year-scoped) events
	var hist_out: Dictionary = _try_historical_event()
	if not hist_out.is_empty():
		_record_last_event(hist_out)
		return hist_out

	# 3. Random weighted event
	var rand_out: Dictionary = _try_random_event()
	if not rand_out.is_empty():
		_record_last_event(rand_out)
		_sync_rng_state()
		return rand_out

	# 4. Fallback: council event (8% chance)
	if event_rng != null and event_rng.randf_range(0.0, 1.0) < 0.08:
		var ce: Dictionary = _build_council_event()
		game_state.pending_event = ce
		_sync_rng_state()
		_record_last_event(ce)
		return {
			"type": "event",
			"id": str(ce.get("id", "")),
			"title": ce.get("title", "Rada županov"),
			"text": ce.get("text", ""),
			"body": ce.get("text", ""),
			"art_id": ce.get("art_id", ""),
			"choices": ce.get("choices", {}),
		}

	return {"type": "event", "id": "", "title": "", "text": "", "body": "", "art_id": "", "choices": []}


# No-immediate-repeat guard
func _record_last_event(report: Dictionary) -> void:
	var eid: String = str(report.get("id", ""))
	if eid != "":
		game_state.last_event_id = eid


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
	var m: int = game_state.month
	for cat in _catalog:
		if typeof(cat) != TYPE_DICTIONARY:
			continue
		var eid: String = str(cat.get("id", ""))
		var conds = cat.get("conditions", {})
		if typeof(conds) != TYPE_DICTIONARY:
			continue

		# Block on unknown condition keys — never silently pass.
		if _has_unknown_conditions(conds):
			continue

		# Evaluate all known condition types; skip if any fail.
		if !_evaluate_conditions(conds):
			continue  # skip; event can retry later if conditions change

		var req_year: int = int(conds.get("year", 0))
		if req_year == 0:
			continue
		if y != req_year:
			continue
		# Month check: if month is specified (> 0), it must match current month
		var req_month: int = int(conds.get("month", 0))
		if req_month > 0 and m != req_month:
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
	if event_rng == null:
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
		if typeof(conds) != TYPE_DICTIONARY:
			continue

		# Block on unknown condition keys — never silently pass.
		if _has_unknown_conditions(conds):
			continue

		# Evaluate all known condition types; skip if any fail.
		if !_evaluate_conditions(conds):
			continue

		var ymin: int = int(conds.get("yearMin", 0))
		if ymin > 0 and game_state.year < ymin:
			continue
		var ymax: int = int(conds.get("yearMax", 0))
		if ymax > 0 and game_state.year > ymax:
			continue
		# P1 kontrakt §1.2: exact year must match
		var req_year: int = int(conds.get("year", 0))
		if req_year > 0 and game_state.year != req_year:
			continue
		# P1 kontrakt §1.8: once:true already-fired events excluded
		if bool(cat.get("once", false)) and game_state.triggered_events.has(eid):
			continue
		var cooldown: int = int(cat.get("cooldownTicks", 0))
		if cooldown > 0:
			var cooldowns: Dictionary = game_state.event_cooldowns
			var last: int = int(cooldowns.get(eid, 0))
			if game_state.year * 12 + game_state.month < last + cooldown:
				continue
		# No-immediate-repeat guard (P1 kontrakt §1.6)
		if eid == game_state.last_event_id and eid != "":
			continue
		var w: int = int(cat.get("weight", 1))
		if w <= 0:
			continue
		candidates.append(cat)
		total_weight += w
	if candidates.is_empty():
		return {}
	var roll: int = event_rng.randi_range(1, total_weight)
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
		"id": str(cat.get("id", "")),
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

	# Apply zupaLoyalty effect
	if choice_dict.has("zupaLoyalty"):
		var zl_v = choice_dict.get("zupaLoyalty", {})
		if typeof(zl_v) == TYPE_DICTIONARY:
			var zl: Dictionary = zl_v
			var provs: Dictionary = game_state.provinces
			for pid in zl.keys():
				if provs.has(pid):
					var delta: int = int(zl.get(pid, 0))
					var p: Dictionary = provs[pid]
					p["loyalty"] = clampf(float(p.get("loyalty", 50)) + float(delta), 0.0, 100.0)

	# Apply moodChanges to factions
	if choice_dict.has("moodChanges"):
		var mc_v = choice_dict.get("moodChanges", {})
		if typeof(mc_v) == TYPE_DICTIONARY:
			var mc: Dictionary = mc_v
			_lookup_and_apply_mood(mc)

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

	var eid: String = str(pending.get("id", ""))
	if eid != "":
		var cooldowns: Dictionary = game_state.event_cooldowns
		cooldowns[eid] = game_state.year * 12 + game_state.month
		game_state.event_cooldowns = cooldowns

	# Build narration hook context
	var province_ids: Array = []
	if choice_dict.has("zupaLoyalty") and typeof(choice_dict["zupaLoyalty"]) == TYPE_DICTIONARY:
		var zl_dict: Dictionary = choice_dict["zupaLoyalty"]
		for k in zl_dict.keys():
			province_ids.append(str(k))

	var faction_ids: Array = []
	if choice_dict.has("moodChanges") and typeof(choice_dict["moodChanges"]) == TYPE_DICTIONARY:
		var mc_dict: Dictionary = choice_dict["moodChanges"]
		for k in mc_dict.keys():
			var resolved_fid: String = _resolve_faction_id(str(k))
			if resolved_fid != "" and not faction_ids.has(resolved_fid):
				faction_ids.append(resolved_fid)

	var next_ev_str: String = str(choice_dict.get("next_event", ""))

	var hook_context: Dictionary = {
		"year": int(game_state.year),
		"province_ids": province_ids,
		"faction_ids": faction_ids,
		"next_event": next_ev_str,
	}

	# If not a chain event, clear pending
	var has_next: bool = choice_dict.has("next_event")
	if not has_next:
		game_state.pending_event = null
	else:
		pass  # For chain events, mark we resolved this choice

	game_state.resources = resources

	var chronicle: String = str(choice_dict.get("text", ""))
	if chronicle == "":
		chronicle = "Voľba prijatá."

	_sync_rng_state()

	return {
		"ok": true,
		"effect": effect,
		"chronicle": chronicle,
		"event_id": eid,
		"choice_result": choice_id,
		"context": hook_context,
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
	var council_desc: String = "Županka zo Spiša namieta, že kniežacie dary prúdia len do Nitry a pohraničie ostáva napospas osudu. Kniežacia rada žiada rozhodnutie, kam nasmerovať pozornosť dvoru a prostriedky ríše. Nespokojnosť zhromaždených veľmožov môže prerásť do otvoreného odporu, ak knieža nezaujme jasný postoj."
	return {
		"id": "council",
		"title": "Rada županov",
		"text": council_desc,
		"body": council_desc,
		"art_id": "event_council_of_zhupans",
		"choices": {
			"gifts": {
				"id": "gifts",
				"text": "Odmeniť verných županov darmi",
				"effect": {"gold": -400, "prestige": 8},
				"zupaLoyalty": {
					"bratislava": 5, "devin": 5, "gemer": 5, "hont": 5,
					"moravia": 5, "nitra": 5, "novohrad": 5, "spis": 5,
					"tekov": 5, "trencin": 5, "uzhorod": 5, "zemplin": 5
				}
			},
			"fortify": {
				"id": "fortify",
				"text": "Investovať do opevnení pohraničných žúp",
				"effect": {"gold": -100, "prestige": -4},
				"zupaLoyalty": {"gemer": 10, "novohrad": 10, "uzhorod": 10, "zemplin": 10}
			},
			"taxes": {
				"id": "taxes",
				"text": "Odmietnuť žiadosti a zvýšiť dane",
				"effect": {"gold": 200},
				"zupaLoyalty": {
					"bratislava": -15, "devin": -15, "gemer": -15, "hont": -15,
					"morava": -15, "nitra": -15, "novohrad": -15, "spis": -15,
					"tekov": -15, "trencin": -15, "uzhorod": -15, "zemplin": -15
				}
			}
		}
	}


func _lookup_and_apply_mood(mc: Dictionary) -> void:
	var factions: Dictionary = game_state.factions
	for faction_key in mc.keys():
		var fid: String = _resolve_faction_id(str(faction_key))
		if fid == "" or not factions.has(fid):
			continue
		var mood_mods: Dictionary = mc[faction_key] if typeof(mc[faction_key]) == TYPE_DICTIONARY else {}
		var f: Dictionary = factions[fid]
		var mood: float = float(f.get("mood", 50))
		if mood_mods.has("trust"):
			mood += float(mood_mods["trust"]) * 0.3
		if mood_mods.has("loyalty"):
			mood += float(mood_mods["loyalty"]) * 0.4
		if mood_mods.has("fear"):
			mood += float(mood_mods["fear"]) * 0.15
		if mood_mods.has("anger"):
			mood -= float(mood_mods["anger"]) * 0.3
		f["mood"] = clampf(mood, 0.0, 100.0)


func _resolve_faction_id(name_or_id: String) -> String:
	# Direct match first
	if game_state.factions.has(name_or_id):
		return name_or_id
	# Common aliases
	var lower: String = name_or_id.to_lower()
	if lower in ["byzantium", "byzantskí", "konštantínopol"]:
		return "byzantium"
	if lower in ["franks", "franky", "frankia", "nemeckí"]:
		return "franks"
	if lower in ["hungary", "maďari", "bogatovci"]:
		return "hungary"
	if lower in ["moravia", "hráč", "župani"]:
		return "moravia"
	if lower in ["bavaria", "bavorsko"]:
		return "bavaria"
	if lower in ["poland", "poľsko"]:
		return "poland"
	if lower in ["bohemia", "čechy"]:
		return "bohemia"
	return ""


# Public API: evaluate_conditions without consuming anything — for testing.
func evaluate_conditions_for_test(conds: Dictionary) -> bool:
	return _evaluate_conditions(conds)
