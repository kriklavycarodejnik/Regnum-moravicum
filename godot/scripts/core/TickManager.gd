# scripts/core/TickManager.gd
class_name TickManager
extends RefCounted

signal tick_completed(tick_report: Dictionary)

var game_state
var economy
var nobility
var narration
var save_manager


func _init(state, eco, nob, nar, save = null) -> void:
	game_state = state
	economy = eco
	nobility = nob
	narration = nar
	save_manager = save


func advance_time() -> void:
	game_state.month += 1
	if game_state.month > 12:
		game_state.month = 1
		game_state.year += 1


func process_tick() -> Dictionary:
	advance_time()

	var report := {
		"year": game_state.year,
		"month": game_state.month
	}

	report["economy"] = economy.process_economy()
	report["nobility"] = nobility.process_nobility()

	var chronicle_text: String = narration.generate_chronicle(report)
	report["chronicle"] = chronicle_text
	if chronicle_text != "":
		game_state.chronicle.append({
			"year": game_state.year,
			"month": game_state.month,
			"text": chronicle_text
		})

	if save_manager != null and game_state.month == 12:
		save_manager.autosave_if_year_end(game_state)

	tick_completed.emit(report)
	return report
