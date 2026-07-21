# scripts/core/TickManager.gd
class_name TickManager
extends RefCounted

signal tick_completed(tick_report: Dictionary)

var game_state: GameState
var economy: EconomyManager
var nobility: NobilityManager
var narration: NarrationManager
var save_manager: SaveManager


func _init(
	state: GameState,
	eco: EconomyManager,
	nob: NobilityManager,
	nar: NarrationManager,
	save: SaveManager = null
) -> void:
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

	# M2 fázy
	report["economy"] = economy.process_economy()
	report["nobility"] = nobility.process_nobility()

	# Kronika po výsledkoch
	var chronicle_text: String = narration.generate_chronicle(report)
	report["chronicle"] = chronicle_text
	if chronicle_text != "":
		game_state.chronicle.append({
			"year": game_state.year,
			"month": game_state.month,
			"text": chronicle_text
		})

	# Autosave na konci roka
	if save_manager != null and game_state.month == 12:
		save_manager.autosave_if_year_end(game_state)

	tick_completed.emit(report)
	return report
