# scripts/managers/NarrationManager.gd
class_name NarrationManager
extends RefCounted

var game_state: GameState
var recent_templates: Array = []
var max_recent: int = 12

# Placeholder šablóny — neskôr z data/narration/ (126+ z Phase 2)
var templates := {
	"economy": [
		"Krajina pomaly bohatne. Trhy sú plné tovaru.",
		"Úroda bola priemerná. Zásoby vystačia na zimu.",
		"Dane prichádzajú včas. Pokladnica dýcha."
	],
	"succession": [
		"{name} zomrel. Dynastia smúti.",
		"Smrť {name} zasiahla dvor. Prestíž klesla.",
		"Pohreb {name} zhromaždil šľachtu z celej Moravy."
	],
	"generic": [
		"Mesiac ubehol v pokoji.",
		"Správy z hraníc sú tiché.",
		"Dvor žije bežným rytmom."
	]
}


func _init(state: GameState) -> void:
	game_state = state


func _pick_template(category: String) -> String:
	var pool: Array = templates.get(category, templates["generic"])
	if pool.is_empty():
		return ""

	var candidates: Array = []
	for t in pool:
		if not recent_templates.has(t):
			candidates.append(t)
	if candidates.is_empty():
		candidates = pool

	var chosen: String = str(candidates[randi() % candidates.size()])
	recent_templates.append(chosen)
	if recent_templates.size() > max_recent:
		recent_templates.pop_front()
	return chosen


func generate_from_report(tick_report: Dictionary) -> String:
	var lines: Array = []

	if tick_report.has("economy"):
		lines.append(_pick_template("economy"))

	if tick_report.has("nobility"):
		var deaths: Array = tick_report["nobility"].get("deaths", [])
		for d in deaths:
			if typeof(d) != TYPE_DICTIONARY:
				continue
			var t: String = _pick_template("succession")
			t = t.replace("{name}", str(d.get("dead_noble", "šľachtic")))
			lines.append(t)

	if lines.is_empty():
		lines.append(_pick_template("generic"))

	return "\n".join(lines)


func generate_chronicle(tick_report: Dictionary) -> String:
	return generate_from_report(tick_report)


func generate_chronicle_endgame(is_victory: bool, is_defeat: bool) -> String:
	if is_victory:
		return "Dynastia Mojmírovcov pretrvala. Veľká Morava stojí."
	if is_defeat:
		return "Dynastia zanikla. Kronika sa končí v tichu."
	return ""
