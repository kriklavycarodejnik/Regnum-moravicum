# tools/test_succession_seniority.gd
# Headless unit test — seniorátna vetva SuccessionManager:
# najstarší mužský príbuzný, nie syn; deterministický test s fixným seedom.
extends SceneTree

const SuccessionManager := preload("res://scripts/managers/SuccessionManager.gd")
const GameState := preload("res://scripts/core/GameState.gd")
const SaveManager := preload("res://scripts/core/SaveManager.gd")

var _ok: bool = true


func check(cond: bool, label: String) -> void:
	if not cond:
		push_error("FAIL: " + label)
		print("FAIL: ", label)
		_ok = false


func _make_world(seed_val: int) -> Array:
	"""Vráti [gs, sm, rng] s predvolenými nobless (Mojmír II. ruler, Rastislav syn, Predslav strýko, seniority)."""
	var gs = GameState.new()
	var save = SaveManager.new()
	save._init(seed_val)
	var rng = save.get_rng()
	var sm = SuccessionManager.new(gs, rng)
	sm.set_succession_type("seniority")

	gs.nobles["mojmir_ii"] = {
		"id": "mojmir_ii",
		"name": "Mojmír II.",
		"birth_year": 870,
		"is_ruler": true,
		"dynasty_id": "mojmir",
		"prestige": 50,
		"gender": "male"
	}
	# Syn — mladší, seniorita musí dať prednosť strýkovi
	gs.nobles["rastislav"] = {
		"id": "rastislav",
		"name": "Rastislav",
		"birth_year": 885,
		"is_ruler": false,
		"dynasty_id": "mojmir",
		"prestige": 20,
		"gender": "male"
	}
	# Strýko — najstarší žijúci mužský príbuzný
	gs.nobles["predslav"] = {
		"id": "predslav",
		"name": "Predslav",
		"birth_year": 860,
		"is_ruler": false,
		"dynasty_id": "mojmir",
		"prestige": 40,
		"gender": "male"
	}
	return [gs, sm, rng]


func _init() -> void:
	print("=== Test Succession Seniority ===")

	# --- T1: Seniority vyberie najstaršieho mužského (strýko pred synom) ---
	var w = _make_world(42)
	var gs = w[0]
	var sm = w[1]
	var heir: Dictionary = sm.get_heir()
	check(heir.get("id", "") == "predslav", "T1: seniority picks oldest male (predslav, not rastislav)")
	check(heir.get("birth_year", 0) == 860, "T1: predslav born 860")
	print("T1 OK: heir = ", heir.get("id", "?"))

	# --- T2: Ženy sú vylúčené aj keď sú staršie ---
	var w2 = _make_world(42)
	var gs2 = w2[0]
	var sm2 = w2[1]
	gs2.nobles["bohdana"] = {
		"id": "bohdana",
		"name": "Bohdana",
		"birth_year": 850,
		"is_ruler": false,
		"dynasty_id": "mojmir",
		"prestige": 40,
		"gender": "female"
	}
	heir = sm2.get_heir()
	check(heir.get("id", "") == "predslav", "T2: female older than males excluded (predslav still heir)")
	print("T2 OK: female excluded, heir = ", heir.get("id", "?"))

	# --- T3: Iná dynastia vylúčená ---
	var w3 = _make_world(42)
	var gs3 = w3[0]
	var sm3 = w3[1]
	gs3.nobles["arnold"] = {
		"id": "arnold",
		"name": "Arnold",
		"birth_year": 850,
		"is_ruler": false,
		"dynasty_id": "arnoldovci",
		"prestige": 60,
		"gender": "male"
	}
	heir = sm3.get_heir()
	check(heir.get("id", "") == "predslav", "T3: other dynasty noble excluded (predslav still heir)")
	print("T3 OK: other dynasty excluded, heir = ", heir.get("id", "?"))

	# --- T4: Determinizmus — rovnaký seed = rovnaký dedič ---
	var w4a = _make_world(42)
	var sm4a = w4a[1]
	var w4b = _make_world(42)
	var sm4b = w4b[1]
	var heir_a: Dictionary = sm4a.get_heir()
	var heir_b: Dictionary = sm4b.get_heir()
	check(heir_a.get("id", "") == heir_b.get("id", ""), "T4: same seed → same heir id")
	check(heir_a.get("birth_year", 0) == heir_b.get("birth_year", 0), "T4: same seed → same heir birth_year")
	print("T4 OK: determinism verified (seed 42, heir=", heir_a.get("id", "?"), ")")

	# --- T5: Viac kandidátov, najstarší vyhráva ---
	var w5 = _make_world(42)
	var gs5 = w5[0]
	var sm5 = w5[1]
	gs5.nobles["svorad"] = {
		"id": "svorad", "name": "Svorad", "birth_year": 845,
		"is_ruler": false, "dynasty_id": "mojmir", "prestige": 55, "gender": "male"
	}
	gs5.nobles["horislav"] = {
		"id": "horislav", "name": "Horislav", "birth_year": 855,
		"is_ruler": false, "dynasty_id": "mojmir", "prestige": 45, "gender": "male"
	}
	heir = sm5.get_heir()
	check(heir.get("id", "") == "svorad", "T5: oldest of 5 candidates (svorad 845)")
	check(heir.get("birth_year", 0) == 845, "T5: svorad born 845")
	print("T5 OK: oldest of 5 = ", heir.get("id", "?"), " (", heir.get("birth_year", 0), ")")

	# --- T6: Gender absent → predvolene male ---
	var w6 = _make_world(42)
	var gs6 = w6[0]
	var sm6 = w6[1]
	gs6.nobles["starcek"] = {
		"id": "starcek", "name": "Starček", "birth_year": 840,
		"is_ruler": false, "dynasty_id": "mojmir", "prestige": 30
	}
	heir = sm6.get_heir()
	check(heir.get("id", "") == "starcek", "T6: noble without gender field defaults to male (starcek 840)")
	print("T6 OK: absent gender = male, heir = ", heir.get("id", "?"))

	# --- T7: Iba muži z inej dynastie → prázdny dedič ---
	var w7 = _make_world(42)
	var gs7 = w7[0]
	var sm7 = w7[1]
	for nid in ["predslav", "rastislav"]:
		gs7.nobles[nid]["dynasty_id"] = "ina_dynastia"
	heir = sm7.get_heir()
	check(heir.is_empty(), "T7: only males from other dynasty → empty heir")
	print("T7 OK: no same-dynasty males → empty heir")

	# --- T8: Iba ženy v dynastii → prázdny dedič ---
	var w8 = _make_world(42)
	var gs8 = w8[0]
	var sm8 = w8[1]
	gs8.nobles.erase("predslav")
	gs8.nobles.erase("rastislav")
	gs8.nobles["bohdana"] = {
		"id": "bohdana", "name": "Bohdana", "birth_year": 850,
		"is_ruler": false, "dynasty_id": "mojmir", "prestige": 40, "gender": "female"
	}
	heir = sm8.get_heir()
	check(heir.is_empty(), "T8: only females in dynasty → empty heir")
	print("T8 OK: only females → empty heir")

	# --- T9: process_succession — žiadny ruler, žiadny dedič → dynastic_crisis ---
	var w9 = _make_world(42)
	var gs9 = w9[0]
	var sm9 = w9[1]
	gs9.nobles["mojmir_ii"]["is_ruler"] = false
	var report: Dictionary = sm9.process_succession()
	# get_heir() returns empty when no ruler exists (cannot determine dynasty), so crisis path
	check(report.get("event", "") == "dynastic_crisis", "T9: no ruler + get_heir returns empty → dynastic_crisis")
	check(report.get("heir", {}).is_empty() == true, "T9: heir is empty in crisis report")
	check(report.get("type", "") == "succession", "T9: report type = succession")
	print("T9 OK: no ruler + no heir → dynastic crisis")

	# --- T10: process_succession — živý vládca → len report, žiaden transfer ---
	var w10 = _make_world(42)
	var gs10 = w10[0]
	var sm10 = w10[1]
	report = sm10.process_succession()
	var ruler: Dictionary = sm10._get_current_ruler()
	check(ruler.get("is_ruler", false) == true, "T10: ruler stays ruler")
	check(report.get("new_ruler", null) == null, "T10: no new_ruler when ruler alive")
	check(report.get("heir", {}).get("id", "") == "predslav", "T10: heir reported as predslav")
	check(report.get("type", "") == "succession", "T10: report type = succession")
	print("T10 OK: alive ruler → no transfer, heir = ", report.get("heir", {}).get("id", "?"))

	# --- T11: Deterministický seed — dve volania get_heir() rovnaký výsledok ---
	var w11 = _make_world(42)
	var sm11 = w11[1]
	var call1: Dictionary = sm11.get_heir()
	var call2: Dictionary = sm11.get_heir()
	check(call1.get("id", "") == call2.get("id", ""), "T11: same instance, two calls = same heir")
	check(call1.get("birth_year", 0) == call2.get("birth_year", 0), "T11: same instance, same birth_year")
	print("T11 OK: two get_heir() calls on same instance = same result")

	# --- T12: get_heir() keď ruler neexistuje → prázdny dict ---
	var w12 = _make_world(42)
	var gs12 = w12[0]
	var sm12 = w12[1]
	gs12.nobles["mojmir_ii"]["is_ruler"] = false
	heir = sm12.get_heir()
	check(heir.is_empty(), "T12: get_heir returns empty when no ruler (cannot determine dynasty)")
	print("T12 OK: get_heir() with no ruler → empty")

	# --- T13: Dvaja kandidáti rovnakého veku — seniorita vyberie prvého v poradí ---
	var w13 = _make_world(42)
	var gs13 = w13[0]
	var sm13 = w13[1]
	# Odstránime rastislava a predslava, pridáme dvojičky narodené v 860
	gs13.nobles.erase("rastislav")
	gs13.nobles.erase("predslav")
	gs13.nobles["dvojc_a"] = {
		"id": "dvojc_a", "name": "dvojča A", "birth_year": 860,
		"is_ruler": false, "dynasty_id": "mojmir", "prestige": 30, "gender": "male"
	}
	gs13.nobles["dvojc_b"] = {
		"id": "dvojc_b", "name": "dvojča B", "birth_year": 860,
		"is_ruler": false, "dynasty_id": "mojmir", "prestige": 25, "gender": "male"
	}
	heir = sm13.get_heir()
	check(heir.get("id", "") == "dvojc_a" or heir.get("id", "") == "dvojc_b", "T13: same-age candidates → one of them is chosen")
	check(not heir.is_empty(), "T13: heir is non-empty for same-age candidates")
	print("T13 OK: same-age male candidates → heir = ", heir.get("id", "?"))

	# --- Finále ---
	if _ok:
		print("SUCCESSION_SENIORITY_PASS")
		quit()
	else:
		print("SUCCESSION_SENIORITY_FAIL")
		quit(1)