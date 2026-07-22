# scripts/core/TickManager.gd
class_name TickManager
extends RefCounted

signal tick_completed(tick_report: Dictionary)

const _GameState := preload("res://scripts/core/GameState.gd")

var game_state
var economy
var nobility
var narration
var events
var diplomacy
var war
var succession
var religion
var victory
var army
var campaign
var save_manager


func _init(
	state: RefCounted = null,
	eco = null,
	nob = null,
	nar = null,
	ev = null,
	dip = null,
	w = null,
	suc = null,
	rel = null,
		vic = null,
		arm = null,
		camp = null,
		save = null
) -> void:
	if state != null:
		game_state = state
	if eco != null:
		economy = eco
	if nob != null:
		nobility = nob
	if nar != null:
		narration = nar
	if ev != null:
		events = ev
	if dip != null:
		diplomacy = dip
	if w != null:
		war = w
	if suc != null:
		succession = suc
	if rel != null:
		religion = rel
	if vic != null:
		victory = vic
	if arm != null:
		army = arm
	if camp != null:
		campaign = camp
	if save != null:
		save_manager = save


func advance_time() -> void:
	var current_month: int = game_state.month
	current_month += 1
	if current_month > 12:
		current_month = 1
		var current_year: int = game_state.year
		current_year += 1
		game_state.year = current_year
	game_state.month = current_month


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
	if succession != null:
		report["succession"] = succession.process_succession()
	if religion != null:
		report["religion"] = religion.process_religion()
	if victory != null:
		report["victory"] = victory.check_victory()
	if army != null:
		report["armies"] = army.process_armies()
	if campaign != null:
		report["campaign"] = campaign.process_campaign()

	var chronicle_text: String = narration.generate_chronicle(report)
	report["chronicle"] = chronicle_text
	if chronicle_text != "":
		var chronicle: Array = game_state.chronicle
		chronicle.append({
			"year": game_state.year,
			"month": game_state.month,
			"text": chronicle_text
		})
		game_state.chronicle = chronicle

	if save_manager != null and (game_state.month) == 12:
		save_manager.autosave_if_year_end(game_state)

	tick_completed.emit(report)
	return report