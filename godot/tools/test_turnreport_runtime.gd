# tools/test_turnreport_runtime.gd
# Headless runtime test: Main.tscn tick wiring + TurnReport visibility + CTA conditional
# Spusta sa ako scene (autoloady GameManager, ArtCatalog su k dispozicii):
#   godot --headless --path . res://tools/test_turnreport_runtime.tscn
extends Node

var _failures: int = 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: ", label)
	else:
		print("  FAIL: ", label)
		_failures += 1

func _ready() -> void:
	print("=== TurnReport runtime behavior test (autoloads enabled) ===")

	# Ensure clean state — tutorial would overlay and interfere
	if GameManager != null and GameManager.game_state != null:
		GameManager.game_state.tutorial_done = true
		GameManager.game_state.pending_event = null
	else:
		push_error("GameManager autoload not available")
		print("FAIL: GameManager autoload not available")
		_failures += 1

	# Load and instantiate Main.tscn
	var MainScene := preload("res://scenes/main/Main.tscn")
	var main = MainScene.instantiate()
	add_child(main)

	# Main._ready() has run by now — access its children
	var turn_report = main.get_node("TurnReport")
	var next_month_btn = main.get_node("UI/PrimaryRow/NextMonthButton")
	var skirmish_btn = main.get_node("UI/ToolsRow/SkirmishButton")
	var event_panel = main.get_node("UI/Body/MainColumn/EventPanel")

	print("--- Phase 1: Initial state ---")
	check(not turn_report.visible, "1.1 TurnReport initially hidden")
	check(not event_panel.visible, "1.2 EventPanel initially hidden")
	check(not next_month_btn.disabled, "1.3 NextMonthButton initially enabled")
	check(not skirmish_btn.disabled, "1.4 SkirmishButton initially enabled")

	print("--- Phase 2: After _on_next_month() tick ---")
	main._on_next_month()

	# turn_report must be visible after every tick (even if an event also appeared)
	check(turn_report.visible, "2.1 TurnReport visible after tick (_on_next_month)")
	check(next_month_btn.disabled, "2.2 NextMonthButton disabled during TurnReport")
	check(skirmish_btn.disabled, "2.3 SkirmishButton disabled during TurnReport")

	print("--- Phase 3: TurnReport dismiss via CTA (same as player click) ---")
	# Record whether event_panel was visible (may be set by _show_event in the tick)
	var event_was_visible: bool = event_panel.visible

	# Call _on_cta() — this emits continue_pressed signal (-> Main handler runs)
	# AND calls hide() — same flow as player clicking "Pokračovať"
	turn_report._on_cta()
	check(not turn_report.visible, "3.1 TurnReport hidden after CTA dismiss")

	if not event_was_visible:
		# No event triggered — buttons should re-enable
		check(not next_month_btn.disabled, "3.2 NextMonthButton re-enabled after dismiss (no event)")
		check(not skirmish_btn.disabled, "3.3 SkirmishButton re-enabled after dismiss (no event)")
	else:
		# An event was triggered — buttons stay disabled (tested in phase 4)
		print("  INFO: Event was visible after tick — buttons stay disabled (tested in Phase 4)")
		check(next_month_btn.disabled, "3.2 NextMonthButton stays disabled (event pending)")
		check(skirmish_btn.disabled, "3.3 SkirmishButton stays disabled (event pending)")

	print("--- Phase 4: CTA conditional — event_panel visible ---")
	# Ensure event_panel is visible (if it wasn't from the tick, force it)
	if not event_panel.visible:
		event_panel.visible = true

	# Re-show TurnReport (it was hidden by dismiss in phase 3)
	main.turn_report.show_report({
		"year": 902, "month": 3,
		"resources_delta": {},
		"narration": "Test narration.",
	})
	check(turn_report.visible, "4.1 TurnReport visible for CTA conditional test")

	# Dismiss via CTA while event_panel is visible — buttons MUST stay disabled
	turn_report._on_cta()
	check(not turn_report.visible, "4.2 TurnReport hidden after CTA dismiss")
	check(next_month_btn.disabled, "4.3 NextMonthButton disabled — event_panel visible after dismiss")
	check(skirmish_btn.disabled, "4.4 SkirmishButton disabled — event_panel visible after dismiss")

	print("--- Phase 5: Event resolved — buttons re-enabled ---")
	# Simulate _resolve(): hide event panel
	event_panel.visible = false

	# Re-show TurnReport again for a clean dismiss
	main.turn_report.show_report({
		"year": 902, "month": 3,
		"resources_delta": {},
		"narration": "Test narration.",
	})
	check(turn_report.visible, "5.1 TurnReport visible")
	turn_report._on_cta()
	check(not turn_report.visible, "5.2 TurnReport hidden after CTA dismiss")
	check(not next_month_btn.disabled, "5.3 NextMonthButton re-enabled — event resolved")
	check(not skirmish_btn.disabled, "5.4 SkirmishButton re-enabled — event resolved")

	# Clean exit
	if _failures == 0:
		print("TURNREPORT_RUNTIME_PASS")
		get_tree().quit(0)
	else:
		print("TURNREPORT_RUNTIME_FAIL: %d failure(s)" % _failures)
		get_tree().quit(1)