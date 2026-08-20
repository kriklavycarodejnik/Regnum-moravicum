# scripts/managers/NarrationManager.gd
class_name NarrationManager
extends RefCounted

const _GameState := preload("res://scripts/core/GameState.gd")

# Priorita sub-reportov: prvý non-prázdny vyhrá.
const _PRIORITY: Array = ["event", "war", "diplomacy", "succession", "religion", "nobility", "economy", "armies", "campaign", "victory"]

const PROVINCE_NAMES := {
	"morava": "Morava",
	"nitra": "Nitra",
	"bratislava": "Bratislava",
	"devin": "Devín",
	"trencin": "Trenčín",
	"tekov": "Tekov",
	"hont": "Hont",
	"novohrad": "Novohrad",
	"gemer": "Gemer",
	"spis": "Spiš",
	"zemplin": "Zemplín",
	"uzhorod": "Užhorod"
}

const PROVINCE_LOCATIVES := {
	"morava": "na Morave",
	"nitra": "v Nitre",
	"bratislava": "v Bratislave",
	"devin": "na Devíne",
	"trencin": "v Trenčíne",
	"tekov": "v Tekove",
	"hont": "v Honte",
	"novohrad": "v Novohrade",
	"gemer": "v Gemeri",
	"spis": "na Spiši",
	"zemplin": "v Zemplíne",
	"uzhorod": "v Užhorode"
}

const FACTION_NAMES := {
	"moravia": "Veľká Morava",
	"franks": "Franská ríša",
	"bavaria": "Bavorsko",
	"hungary": "Maďari",
	"poland": "Poľsko",
	"bohemia": "Čechy",
	"byzantium": "Byzantská ríša"
}

var game_state
var rng: RandomNumberGenerator
var recent_templates: Array = []


func _init(state: RefCounted = null, rng_ref: RandomNumberGenerator = null) -> void:
	if state != null:
		game_state = state
	if rng_ref != null:
		rng = rng_ref


# generate_chronicle acceptuje celý tick report (s kľúčmi year, month, economy,
# nobility, war, event, diplomacy, succession, religion, victory, armies,
# campaign). Iteruje cez sub-reporty v prioritnom poradí a vráti prvý
# non-prázdny narátiový text. Ak žiadny sub-report nevygeneruje text, vráti "".
func generate_chronicle(report: Dictionary) -> String:
	# Ak report priamo obsahuje "type" (sub-report volaný samostatne),
	# dispatchni ho priamo — spätná kompatibilita so starými volaniami.
	if report.has("type"):
		var direct_text: String = _dispatch_type(str(report.get("type", "")), report)
		if direct_text != "":
			return _apply_anti_repetition(direct_text)
	# Inak iteruj cez sub-reporty v prioritnom poradí.
	for sub_key in _PRIORITY:
		if not report.has(sub_key):
			continue
		var sub_report = report.get(sub_key)
		if typeof(sub_report) != TYPE_DICTIONARY:
			continue
		var sub_type: String = str(sub_report.get("type", ""))
		if sub_type == "":
			continue
		var text: String = _dispatch_type(sub_type, sub_report)
		if text != "":
			return _apply_anti_repetition(text)
	return ""


func _dispatch_type(type_str: String, report: Dictionary) -> String:
	match type_str:
		"economy":
			return _generate_economy_text(report)
		"nobility":
			return _generate_nobility_text(report)
		"diplomacy":
			return _generate_diplomacy_text(report)
		"war":
			return _generate_war_text(report)
		"event":
			return _generate_event_text(report)
		"succession":
			return _generate_succession_text(report)
		"religion":
			return _generate_religion_text(report)
		"victory":
			return _generate_victory_text(report)
		"armies":
			return _generate_armies_text(report)
		"campaign":
			return _generate_campaign_text(report)
		_:
			return ""


func _apply_anti_repetition(template: String) -> String:
	# Anti-repetition: ak sa rovnaká šablóna nedávno objavila, vráť "".
	if recent_templates.has(template):
		return ""
	recent_templates.append(template)
	if recent_templates.size() > 12:
		recent_templates.pop_front()
	return template


func _get_province_name(province_id: String) -> String:
	if PROVINCE_NAMES.has(province_id):
		return PROVINCE_NAMES[province_id]
	return province_id.capitalize()


func _get_province_locative(province_id: String) -> String:
	if PROVINCE_LOCATIVES.has(province_id):
		return PROVINCE_LOCATIVES[province_id]
	return "v kraji " + _get_province_name(province_id)


func _generate_economy_text(report: Dictionary) -> String:
	var keys: Array = report.get("prosperity_growth", {}).keys()
	if keys.is_empty():
		return "Sypárnice v Nitre držia zásoby, no župné dvorce žiadajú novú úrodu."
	var pid: String = str(keys[0])
	if rng != null and keys.size() > 1:
		pid = str(keys[rng.randi_range(0, keys.size() - 1)])
	var loc: String = _get_province_locative(pid)
	return "Sypárnice %s sa plnia, no župan z Gemera poslal posla so žiadosťou o zrno." % loc


func _generate_nobility_text(report: Dictionary) -> String:
	var deaths: Array = report.get("deaths", [])
	if deaths.size() > 0:
		var death: Dictionary = deaths[0]
		var dname: String = str(death.get("name", "Veľmož"))
		return "%s z rodu Mojmírovcov skonal v Nitre — dvor nosí smútok a zvony bijú." % dname
	var births: Array = report.get("births", [])
	if births.size() > 0:
		var birth: Dictionary = births[0]
		var bname: String = str(birth.get("name", "Nový potomok"))
		return "Na nitrianskom hradisku sa narodil %s z mojmírovskej krvi — kňazi slúžia ďakovné modlitby." % bname
	return ""


func _generate_diplomacy_text(report: Dictionary) -> String:
	var mood_changes: Dictionary = report.get("mood_changes", {})
	if mood_changes.is_empty():
		return ""
	if mood_changes.has("bavaria"):
		return "Posolstvo z Regensburgu mlčí — bavorský vojvoda si meria Moravu a vyčkáva na slabosť."
	elif mood_changes.has("franks"):
		return "Z Východofranskej ríše prišli poslovia s chladným pozdravom — hranica na Dunaji zostáva napätá."
	elif mood_changes.has("byzantium"):
		return "Cisársky posol z Konštantínopola priniesol pozdrav od Leva VI. a uisťuje dvor o priateľstve."
	elif mood_changes.has("hungary"):
		return "Z potiských stepí prichádzajú zvesti o pohybe staromaďarských jazdcov."
	return "Posolstvo z Regensburgu mlčí — bavorský vojvoda si meria Moravu a vyčkáva na slabosť."


func _generate_war_text(report: Dictionary) -> String:
	var occupations: Array = report.get("occupations", [])
	var battles: Array = report.get("battles", [])
	if occupations.size() > 0 or report.get("occupation_applied", false):
		var target_loc := "v Zemplíne"
		if occupations.size() > 0 and typeof(occupations[0]) == TYPE_DICTIONARY:
			var opid: String = str(occupations[0].get("province_id", ""))
			if opid != "":
				target_loc = _get_province_locative(opid)
		return "Maďarské čaty vpadli do dvorcov %s — odsúdené pohraničné župy volajú po pomoci." % target_loc
	if battles.size() > 0:
		var battle: Dictionary = battles[0]
		var winner: String = str(battle.get("winner", ""))
		if winner == "attacker":
			return "Riečna obrana na Devíne čelí náporu maďarských šípov — nepriateľ prelomil predsunuté línie."
		elif winner == "defender":
			return "Bojovníci na hradbách Devína odrazili maďarský útok a držia pozície."
		return "Riečna obrana na Devíne čelí náporu maďarských šípov — bojovníci držia valy."
	return ""


func _generate_event_text(report: Dictionary) -> String:
	var event_id: String = str(report.get("id", ""))
	var text: String = str(report.get("text", report.get("body", "")))
	if event_id == "" and text == "":
		return ""
	if text.strip_edges() != "":
		return "Na kniežacom dvore v Nitre: %s" % text
	return "Na kniežacom dvore v Nitre zasadla rada veľmožov a posudzuje stav Moravy."


func _generate_succession_text(report: Dictionary) -> String:
	var new_ruler = report.get("new_ruler", null)
	if new_ruler != null and typeof(new_ruler) == TYPE_DICTIONARY and not new_ruler.is_empty():
		var rname: String = str(new_ruler.get("name", "Nový panovník"))
		return "%s zasadá na stolec Veľkej Moravy — celý nitriansky dvor prisahá vernosť." % rname
	return ""


func _generate_religion_text(report: Dictionary) -> String:
	var changes: Array = report.get("changes", [])
	if changes.is_empty():
		return ""
	var dominant: String = str(report.get("dominant_religion", ""))
	if dominant == "latin" or dominant == "christian":
		return "Kňazi v Nitre vedú spory — latinský obrad súperí so staroslovienčinou a ľud pozorne počúva."
	elif dominant == "orthodox":
		return "V chrámoch znie staroslovanská liturgia cyrilometodského odkazu a posilňuje jednotu Moravy."
	elif dominant == "pagan":
		return "V odľahlých župách sa ľud tajne vracia k starým bohom a obetným hájom, kňazi varujú knieža."
	return "Kňazi v Nitre sa hádajú — latinsky alebo slovansky — a ľud počúva."


func _generate_victory_text(report: Dictionary) -> String:
	if report.get("victory", false):
		var vtype: String = str(report.get("victory_type", ""))
		var vmsg: String = str(report.get("message", ""))
		if vmsg != "":
			return "Morava zvíťazila — %s! Kronika uchová túto slávu naveky." % vmsg
		elif vtype != "":
			return "Morava zvíťazila (%s)! Kronika uchová slávu Mojmírovcov." % vtype
		return "Morava zvíťazila! Kniežatstvo pretrvalo a kronika uchová slávu Mojmírovcov."
	elif report.get("defeat", false):
		var dmsg: String = str(report.get("message", ""))
		if dmsg != "":
			return "Koniec moravskej samostatnosti — %s." % dmsg
		return "Veľká Morava podľahla nepriateľom — pád kniežatstva sa zapísal do dejín."
	return ""


func _generate_armies_text(report: Dictionary) -> String:
	var events: Array = report.get("events", [])
	if events.size() > 0 and typeof(events[0]) == TYPE_DICTIONARY:
		var ev: Dictionary = events[0]
		if ev.get("type", "") == "army_desertion":
			var aid: String = str(ev.get("army_id", "družina"))
			var loss: int = int(ev.get("size_loss", 0))
			return "Moravská družina %s stráca %d bojovníkov pre nedostatok zásob na pohraničí." % [aid, loss]
		return "Na zhromaždisku družín v Nitre panuje ruch — bojovníci pripravujú výstroj."
	return ""


func _generate_campaign_text(report: Dictionary) -> String:
	var events: Array = report.get("events", [])
	if events.is_empty():
		return ""
	var event: Dictionary = events[0]
	var etype: String = str(event.get("type", ""))
	if etype == "siege_tick":
		var target: String = str(event.get("province_id", "pevnosti"))
		return "Obliehanie %s pokračuje — obrancovia na hradbách počítajú ubúdajúce zásoby." % _get_province_locative(target)
	elif etype == "battle":
		return "Na pohraničných poliach sa zrazili prieskumné oddiely — zem duní pod kopytami koní."
	return "Vojnové výpravy na hraniciach Moravy zamestnávajú pohraničné stráže."
