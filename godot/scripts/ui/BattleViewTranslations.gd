# scripts/ui/BattleViewTranslations.gd
# Translation maps shared across UI panels (BattleView, ArmyUI, MapView, Main) and smoke tests.
# No autoload or scene dependencies — safe to load from any context (headless, -s, scene).
extends RefCounted

const WINNER_MAP := {
	"attacker": "útočník",
	"defender": "obranca",
	"decisive_victory": "rozhodujúce víťazstvo",
	"major_victory": "veľké víťazstvo",
	"victory": "víťazstvo",
	"stalemate": "patová situácia",
	"narrow_victory": "tesné víťazstvo",
	"heroic_victory": "hrdinské víťazstvo",
}

const PHASE_MAP := {
	"attack": "útok",
	"counterattack": "protiútok",
	"decision": "rozhodnutie",
}

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
	"uzhorod": "Užhorod",
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
	"uzhorod": "v Užhorode",
}

const FACTION_NAMES := {
	"moravia": "Veľká Morava",
	"franks": "Franská ríša",
	"frankia": "Franská ríša",
	"bavaria": "Bavorsko",
	"hungary": "Maďari",
	"madari": "Maďari",
	"magyars": "Maďari",
	"magyar": "Maďari",
	"poland": "Poľsko",
	"bohemia": "Čechy",
	"byzantium": "Byzantská ríša",
}

const ARMY_STATUS := {
	"idle": "V tábore",
	"marching": "Na pochode",
	"besieging": "Obliehanie",
	"battling": "V boji",
	"disbanded": "Rozpustená",
}

const ARMY_NAMES := {
	"moravia_levy_1": "Nitrianska hotovosť",
	"moravia_feudal_1": "Bratislavská družina",
	"madari_horde_1": "Maďarská horda pri Užhorode",
	"test_army": "Moravská garda",
	"isolated_army": "Pohraničná hliadka",
}

const TEMPLATE_NAMES := {
	"moravia_levy": "Zemská hotovosť",
	"moravia_feudal": "Kniežacia družina",
	"madari_horde": "Kočovná horda",
	"levy": "Zemská hotovosť",
	"feudal": "Kniežacia družina",
	"elite": "Elitná garda",
	"mercenary": "Žoldnieri",
}

const FALLBACK_WINNER := "neznámy výsledok"
const FALLBACK_PHASE := "neznáma fáza"
const FALLBACK_PROVINCE := "Neznáma župa"
const FALLBACK_FACTION := "Neznáma frakcia"
const FALLBACK_ARMY := "Neznámy oddiel"
const FALLBACK_STATUS := "Neznámy stav"


static func translate_winner(w: String) -> String:
	return WINNER_MAP.get(w, FALLBACK_WINNER)


static func translate_phase(p: String) -> String:
	return PHASE_MAP.get(p, FALLBACK_PHASE)


static func sanitize_display_name(raw_name: String, fallback: String) -> String:
	var trimmed := raw_name.strip_edges()
	if trimmed == "" or "_" in trimmed or trimmed == trimmed.to_lower():
		return fallback
	return trimmed


static func translate_province(pid: String, fallback_override: String = "") -> String:
	if PROVINCE_NAMES.has(pid):
		return PROVINCE_NAMES[pid]
	var cleaned := sanitize_display_name(pid, "")
	if cleaned != "":
		return cleaned
	return fallback_override if fallback_override != "" else FALLBACK_PROVINCE


static func translate_province_locative(pid: String) -> String:
	if PROVINCE_LOCATIVES.has(pid):
		return PROVINCE_LOCATIVES[pid]
	return "v neznámej župe"


static func translate_faction(fid: String, fallback_override: String = "") -> String:
	if FACTION_NAMES.has(fid):
		return FACTION_NAMES[fid]
	var cleaned := sanitize_display_name(fid, "")
	if cleaned != "":
		return cleaned
	return fallback_override if fallback_override != "" else FALLBACK_FACTION


static func translate_army_status(status: String) -> String:
	return ARMY_STATUS.get(status, FALLBACK_STATUS)


static func translate_army_name(army: Dictionary, army_id: String = "") -> String:
	var aid: String = army_id
	if aid == "" and typeof(army) == TYPE_DICTIONARY:
		aid = str(army.get("id", ""))

	if ARMY_NAMES.has(aid):
		return ARMY_NAMES[aid]

	var prov_id: String = str(army.get("province_id", "")) if typeof(army) == TYPE_DICTIONARY else ""
	var fac_id: String = str(army.get("faction_id", "")) if typeof(army) == TYPE_DICTIONARY else ""
	var tpl_id: String = str(army.get("template_id", "")) if typeof(army) == TYPE_DICTIONARY else ""

	if tpl_id != "" and TEMPLATE_NAMES.has(tpl_id):
		var tpl_name: String = TEMPLATE_NAMES[tpl_id]
		if prov_id != "":
			return "%s (%s)" % [tpl_name, translate_province(prov_id)]
		return tpl_name

	if fac_id == "hungary" or fac_id == "madari":
		if prov_id != "":
			return "Maďarský oddiel (%s)" % translate_province(prov_id)
		return "Maďarský jazdecký oddiel"

	if prov_id != "":
		return "Družina (%s)" % translate_province(prov_id)

	return FALLBACK_ARMY
