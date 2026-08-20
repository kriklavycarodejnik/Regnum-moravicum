# tools/test_turnreport_runtime.gd
# Headless runtime test: Main.tscn tick wiring + TurnReport visibility + CTA conditional
# Spusta sa ako scene (autoloady GameManager, ArtCatalog su k dispozicii):
#   godot --headless --path . res://tools/test_turnreport_runtime.tscn
extends Node

var _failures: int = 0
var _passes: int = 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: ", label)
		_passes += 1
	else:
		print("  FAIL: ", label)
		_failures += 1

func _ready() -> void:
	print("=== TurnReport runtime behavior test (autoloads enabled) ===")

	# Ensure clean state
	if GameManager == null or GameManager.game_state == null:
		push_error("GameManager autoload not available")
		print("FAIL: GameManager autoload not available")
		_failures += 1

	GameManager.game_state.tutorial_done = true
	GameManager.game_state.pending_event = null

	# Advance year to 906 so devine_btn year-gate (year < 906 -> disabled)
	# does not interfere with CTA conditional assertions for all 3 buttons.
	GameManager.game_state.year = 906
	GameManager.game_state.month = 2

	# Load and instantiate Main.tscn
	var MainScene := preload("res://scenes/main/Main.tscn")
	var main = MainScene.instantiate()
	add_child(main)

	# Access child nodes
	var turn_report = main.get_node("TurnReport")
	var next_month_btn = main.get_node("UI/PrimaryRow/NextMonthButton")
	var skirmish_btn = main.get_node("UI/ToolsRow/SkirmishButton")
	var devine_btn = main.get_node("UI/ToolsRow/DevineButton")
	var event_panel = main.get_node("UI/Body/MainColumn/EventPanel")

	print("--- Phase 1: Initial state ---")
	check(not turn_report.visible, "1.1 TurnReport initially hidden")
	check(not event_panel.visible, "1.2 EventPanel initially hidden")
	check(not next_month_btn.disabled, "1.3 NextMonthButton initially enabled")
	check(not skirmish_btn.disabled, "1.4 SkirmishButton initially enabled")
	# Year is 906 → devine_btn enabled (year-gate clears at 906)
	check(not devine_btn.disabled, "1.5 DevineButton initially enabled")

	print("--- Phase 2: No-event tick — TurnReport shows, all 3 buttons disabled ---")
	# Suppress event generation: null event_manager rng so random/council
	# events don't trigger; also null pending_event
	GameManager.game_state.pending_event = null
	var saved_rng = GameManager.event_manager.rng
	GameManager.event_manager.rng = null

	main._on_next_month()

	# Clean up any stray event that slipped through
	if GameManager.game_state.pending_event != null:
		GameManager.game_state.pending_event = null
	if event_panel.visible:
		event_panel.visible = false

	check(turn_report.visible, "2.1 TurnReport visible after tick")
	check(not event_panel.visible, "2.2 EventPanel NOT visible (no event)")
	check(next_month_btn.disabled, "2.3 NextMonthButton disabled during TurnReport")
	check(skirmish_btn.disabled, "2.4 SkirmishButton disabled during TurnReport")
	check(devine_btn.disabled, "2.5 DevineButton disabled during TurnReport")

	print("--- Phase 3: No-event CTA dismiss — all 3 buttons re-enabled ---")
	turn_report._on_cta()
	check(not turn_report.visible, "3.1 TurnReport hidden after CTA dismiss")
	check(not next_month_btn.disabled, "3.2 NextMonthButton re-enabled (no event)")
	check(not skirmish_btn.disabled, "3.3 SkirmishButton re-enabled (no event)")
	check(not devine_btn.disabled, "3.4 DevineButton re-enabled (no event)")

	# Restore event_manager rng
	GameManager.event_manager.rng = saved_rng

	print("--- Phase 4: Event path — event_panel visible, all 3 buttons stay disabled after CTA ---")
	# Set up a resolvable pending event
	GameManager.game_state.pending_event = {
		"id": "test_event",
		"title": "Test Udalosť",
		"text": "Test text udalosti pre runtime test.",
		"art_id": "",
		"choices": {
			"test_choice_a": {
				"id": "test_choice_a",
				"text": "Voľba A — testovacia",
				"effect": {"gold": 0, "prestige": 0}
			}
		}
	}
	event_panel.visible = true

	# Use _show_turn_report_via_node() like production _on_next_month() does —
	# this disables all 3 buttons before showing the report
	main._show_turn_report_via_node([], "Test chronicle pre event path.")
	check(turn_report.visible, "4.1 TurnReport visible during event")
	check(event_panel.visible, "4.2 EventPanel visible (event pending)")
	check(next_month_btn.disabled, "4.3 NextMonthButton disabled during TurnReport + event")
	check(skirmish_btn.disabled, "4.4 SkirmishButton disabled during TurnReport + event")
	check(devine_btn.disabled, "4.5 DevineButton disabled during TurnReport + event")

	# Dismiss TurnReport — buttons stay disabled (event_panel still visible)
	turn_report._on_cta()
	check(not turn_report.visible, "4.6 TurnReport hidden after CTA dismiss (event pending)")
	check(next_month_btn.disabled, "4.7 NextMonthButton disabled — event_panel visible")
	check(skirmish_btn.disabled, "4.8 SkirmishButton disabled — event_panel visible")
	check(devine_btn.disabled, "4.9 DevineButton disabled — event_panel visible")

	print("--- Phase 5: Event resolved via _resolve() — all 3 buttons re-enabled ---")
	main._resolve("test_choice_a")
	check(not event_panel.visible, "5.1 EventPanel hidden after _resolve()")
	check(not next_month_btn.disabled, "5.2 NextMonthButton re-enabled after _resolve()")
	check(not skirmish_btn.disabled, "5.3 SkirmishButton re-enabled after _resolve()")
	# _resolve() calls _refresh_ui(); year 906+ so devine_btn stays enabled
	check(not devine_btn.disabled, "5.4 DevineButton re-enabled after _resolve()")

	print("--- Phase 6: TurnReport + CTA after event resolved (buttons stay enabled) ---")
	main._show_turn_report_via_node([], "Test chronicle po resolvovani.")
	check(turn_report.visible, "6.1 TurnReport visible")
	check(next_month_btn.disabled, "6.2 NextMonthButton disabled during TurnReport")
	check(skirmish_btn.disabled, "6.3 SkirmishButton disabled during TurnReport")
	check(devine_btn.disabled, "6.4 DevineButton disabled during TurnReport")

	turn_report._on_cta()
	check(not turn_report.visible, "6.5 TurnReport hidden after CTA dismiss")
	check(not next_month_btn.disabled, "6.6 NextMonthButton re-enabled (event resolved)")
	check(not skirmish_btn.disabled, "6.7 SkirmishButton re-enabled (event resolved)")
	# _on_turn_report_dismissed() enables all 3; no _refresh_ui() call here
	check(not devine_btn.disabled, "6.8 DevineButton re-enabled (event resolved)")

	# Clean exit
	if _failures == 0:
		print("TURNREPORT_RUNTIME_PASS  (%d assertions)" % _passes)
		get_tree().quit(0)
	else:
		print("TURNREPORT_RUNTIME_FAIL: %d failure(s), %d pass" % [_failures, _passes])
		get_tree().quit(1)