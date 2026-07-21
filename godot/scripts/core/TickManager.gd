# scripts/core/TickManager.gd
class_name TickManager
extends RefCounted

signal tick_completed(tick_report: Dictionary)

var game_state
var economy
var nobility
var narration
var events
var diplomacy
var war
var save_manager


func _init(
	state,
	eco,
	nob,
	nar,
	ev = null,
	dip = null,
	w = null,
	save = null
) -> void:
	game_state = state
	economy = eco
	nobility = nob
	narration = nar
	events = ev
	diplomacy = dip
	war = w
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

	# Order aligned with architecture (subset of full 14 phases)
	report["economy"] = economy.process_economy()
	report["nobility"] = nobility.process_nobility()
	if diplomacy != null:
		report["diplomacy"] = diplomacy.process_diplomacy()
	if war != null:
		report["war"] = war.process_wars()
	if events != null:
		report["event"] = events.process_events()

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
