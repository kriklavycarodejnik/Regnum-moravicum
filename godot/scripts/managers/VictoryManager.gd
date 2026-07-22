# scripts/managers/VictoryManager.gd
class_name VictoryManager
extends RefCounted

var game_state


func _init(state: RefCounted = null) -> void:
	if state != null:
		game_state = state


func check_victory() -> Dictionary:
	var report := {
		"type": "victory",
		"victory": false,
		"defeat": false,
		"victory_type": "",
		"message": "",
	}
	if game_state == null:
		return report
	if game_state.game_over:
		report.victory = bool(game_state.ending.get("won", false))
		report.defeat = not report.victory
		report.victory_type = str(game_state.ending.get("type", ""))
		report.message = str(game_state.ending.get("message", ""))
		return report

	var resources: Dictionary = game_state.resources
	var provinces: Dictionary = game_state.provinces
	var owned := _count_owned(provinces, "moravia")
	var living_rulers := _count_living_dynasty()

	# --- Defeat ---
	if owned <= 0:
		return _end(false, "no_provinces", "Morava stratila všetky župy. Koniec dynastie na tróne.")
	# prázdny nobles = ešte neinicializované (nie prehra)
	if living_rulers <= 0 and game_state.nobles.size() > 0:
		return _end(false, "dynasty_extinct", "Dynastia vymrela — niet oprávneného dediča.")
	if int(resources.get("gold", 0)) <= -500:
		return _end(false, "bankrupt", "Štátna pokladnica skrachovala. Ríša sa rozpadla.")

	# --- Victory ---
	if int(resources.get("prestige", 0)) >= 100:
		return _end(true, "prestige", "Prestíž Moravy dosiahla legendárnu úroveň.")
	if game_state.year >= 980 and owned >= 10:
		return _end(true, "provinces", "Morava konsolidovala ríšu (980+, 10+ žúp).")
	if game_state.year >= 960 and _count_christian_lean(provinces) >= 9:
		return _end(true, "religion", "Kresťanská os ríše je pevne ukotvená.")
	# Prežiť do roku 1000 s aspoň 1 župou a živou dynastiou
	if game_state.year >= 1000 and owned >= 1 and living_rulers >= 1:
		return _end(true, "survival_1000", "Dynastia prežila do roku 1000. Regnum trvá.")

	return report


func _end(won: bool, vtype: String, message: String) -> Dictionary:
	var report := {
		"type": "victory",
		"victory": won,
		"defeat": not won,
		"victory_type": vtype,
		"message": message,
	}
	game_state.game_over = true
	game_state.ending = {"won": won, "type": vtype, "message": message}
	return report


func _count_owned(provinces: Dictionary, faction: String) -> int:
	var n := 0
	for pid in provinces:
		var p = provinces[pid]
		if typeof(p) == TYPE_DICTIONARY and str(p.get("owner_faction", "")) == faction:
			n += 1
	return n


func _count_christian_lean(provinces: Dictionary) -> int:
	var n := 0
	for pid in provinces:
		var p = provinces[pid]
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var rel = p.get("religion", 50)
		if typeof(rel) == TYPE_INT or typeof(rel) == TYPE_FLOAT:
			if float(rel) >= 45.0:
				n += 1
		else:
			var s: String = str(rel).to_lower()
			if s in ["christian", "latin", "orthodox", "catholic", "byzantine"]:
				n += 1
	return n


func _count_living_dynasty() -> int:
	var n := 0
	var nobles: Dictionary = game_state.nobles
	for nid in nobles:
		var noble = nobles[nid]
		if typeof(noble) != TYPE_DICTIONARY:
			continue
		if str(noble.get("dynasty_id", "")) != "mojmir":
			continue
		if bool(noble.get("dead", false)):
			continue
		n += 1
	return n
