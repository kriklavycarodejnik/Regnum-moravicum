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

# Helper: simulate CTA dismiss via the continue_pressed signal
func _dismiss_report(report_node) -> void:
	report_node.continue_pressed.emit()

func _ready() -> void:
	print("=== TurnReport runtime behavior test (autoloads enabled) ===")

	# Ensure clean state — tutorial would overlay and interfere
	if GameManager != null and GameManager.game_state != null:
		GameManager.game_state.tutorial_done = true
		GameManager.game_state.pending_event = null
		GameManager.game_state.last_event_id = ""
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
	var devine_btn = main.get_node("UI/ToolsRow/DevineButton")
	var event_panel = main.get_node("UI/Body/MainColumn/EventPanel")

	print("--- Phase 1: Initial state ---")
	check(not turn_report.visible, "1.1 TurnReport initially hidden")
	check(not event_panel.visible, "1.2 EventPanel initially hidden")
	check(not next_month_btn.disabled, "1.3 NextMonthButton initially enabled")
	check(not skirmish_btn.disabled, "1.4 SkirmishButton initially enabled")
	# Devin button is year-gated (year < 906 → disabled by _refresh_ui)
	check(devine_btn.disabled, "1.5 DevineButton initially disabled (year 902 < 906 gate)")

	# ──────────────────────────────────────────────────────────────────
	# Phase 2: Tick WITHOUT event (deterministic suppression)
	# ──────────────────────────────────────────────────────────────────
	# Before tick: suppress ALL event generation deterministically:
	#   - Empty the event catalog (no historical or random events)
	#   - Set last_event_id = "council" so the council fallback skips
	#     its 8% chance (no-immediate-repeat guard fires)
	GameManager.game_state.pending_event = null
	GameManager.event_manager._catalog = []
	GameManager.game_state.last_event_id = "council"
	print("--- Phase 2: Tick without event (deterministic) ---")

	main._on_next_month()

	# After tick, no event should have been generated
	check(GameManager.game_state.pending_event == null, "2.0 No pending event after deterministic tick")
	check(turn_report.visible, "2.1 TurnReport visible after tick (_on_next_month)")
	check(not event_panel.visible, "2.2 EventPanel hidden — no event pending")
	# All CTA buttons disabled while TurnReport is showing
	check(next_month_btn.disabled, "2.3 NextMonthButton disabled during TurnReport")
	check(skirmish_btn.disabled, "2.4 SkirmishButton disabled during TurnReport")
	check(devine_btn.disabled, "2.5 DevineButton disabled during TurnReport")

	print("--- Phase 3: CTA dismiss after no-event tick ---")
	_dismiss_report(turn_report)
	check(not turn_report.visible, "3.1 TurnReport hidden after CTA dismiss")
	# No event pending → all three buttons re-enabled
	check(not next_month_btn.disabled, "3.2 NextMonthButton re-enabled (no event)")
	check(not skirmish_btn.disabled, "3.3 SkirmishButton re-enabled (no event)")
	# devine_btn is also re-enabled by _on_turn_report_dismissed();
	# _refresh_ui() is not called again, so the year gate does not re-apply here.
	check(not devine_btn.disabled, "3.4 DevineButton re-enabled (no event)")

	# ──────────────────────────────────────────────────────────────────
	# Phase 4: CTA conditional — event_panel visible
	#   (simulate state after a tick WITH an event: buttons disabled,
	#    event_panel visible, then dismiss TurnReport while event pending)
	# ──────────────────────────────────────────────────────────────────
	print("--- Phase 4: CTA conditional — event_panel visible ---")
	# Simulate the state after a tick with an event
	next_month_btn.disabled = true
	skirmish_btn.disabled = true
	devine_btn.disabled = true
	event_panel.visible = true

	# Re-show TurnReport while event is pending
	main.turn_report.show_report({
		"year": 902, "month": 3,
		"resources_delta": {},
		"narration": "Test narration.",
	})
	check(turn_report.visible, "4.1 TurnReport visible for CTA conditional test")
	check(event_panel.visible, "4.2 EventPanel visible (event pending)")
	check(next_month_btn.disabled, "4.3 NextMonthButton disabled before dismiss")
	check(skirmish_btn.disabled, "4.4 SkirmishButton disabled before dismiss")
	check(devine_btn.disabled, "4.5 DevineButton disabled before dismiss")

	# Dismiss TurnReport while event_panel visible
	_dismiss_report(turn_report)
	check(not turn_report.visible, "4.6 TurnReport hidden after CTA dismiss")
	# Buttons must stay disabled because event_panel is still visible
	check(next_month_btn.disabled, "4.7 NextMonthButton stays disabled after dismiss (event pending)")
	check(skirmish_btn.disabled, "4.8 SkirmishButton stays disabled after dismiss (event pending)")
	check(devine_btn.disabled, "4.9 DevineButton stays disabled after dismiss (event pending)")

	# ──────────────────────────────────────────────────────────────────
	# Phase 5: Event resolved via _resolve()
	#   Create a deterministic pending event, show it via Main wiring,
	#   dismiss TurnReport, call _resolve(), verify buttons re-enable.
	#   Set year to 906 so Devin button year-gate does NOT mask the result.
	# ──────────────────────────────────────────────────────────────────
	print("--- Phase 5: Event resolved via _resolve() ---")

	# Hide event panel and reset state for a fresh resolve test
	event_panel.visible = false
	next_month_btn.disabled = false
	skirmish_btn.disabled = false
	devine_btn.disabled = false
	# Set year to 906 so Devin button becomes valid after _resolve()
	GameManager.game_state.year = 906
	GameManager.game_state.pending_event = null
	# Re-enable the event catalog so _resolve() works with it
	GameManager.event_manager._catalog = []

	# Set up a deterministic event with valid choices in GameState
	var test_event := {
		"id": "test_runtime_event",
		"title": "Testovacia udalosť",
		"body": "Toto je testovacia udalosť pre runtime test.",
		"text": "Toto je testovacia udalosť pre runtime test.",
		"art_id": "",
		"choices": {
			"choice_a": {
				"id": "choice_a",
				"text": "Voľba A — testovacia",
				"effect": {},
			},
			"choice_b": {
				"id": "choice_b",
				"text": "Voľba B — testovacia",
				"effect": {},
			},
		},
	}
	GameManager.game_state.pending_event = test_event

	# Show the event via Main wiring (same path as tick → event)
	main._show_event(GameManager.get_pending_event())
	check(event_panel.visible, "5.1 EventPanel visible after _show_event")

	# Re-show TurnReport and dismiss it while event is still pending
	main.turn_report.show_report({
		"year": 906, "month": 3,
		"resources_delta": {},
		"narration": "Test narration.",
	})
	check(turn_report.visible, "5.2 TurnReport visible before dismiss")

	_dismiss_report(turn_report)
	check(not turn_report.visible, "5.3 TurnReport hidden after CTA dismiss")
	# Buttons stay disabled because event_panel is still visible
	check(next_month_btn.disabled, "5.4 NextMonthButton disabled after dismiss (event pending)")
	check(skirmish_btn.disabled, "5.5 SkirmishButton disabled after dismiss (event pending)")
	check(devine_btn.disabled, "5.6 DevineButton disabled after dismiss (event pending)")

	# Actually resolve the event via Main._resolve() — not a manual flag
	main._resolve("choice_a")
	check(not event_panel.visible, "5.7 EventPanel hidden after _resolve()")
	# After _resolve(), all three buttons should be re-enabled.
	# Year 906 means Devin button year-gate (year >= 906) does NOT disable it.
	check(not next_month_btn.disabled, "5.8 NextMonthButton re-enabled after _resolve")
	check(not skirmish_btn.disabled, "5.9 SkirmishButton re-enabled after _resolve")
	check(not devine_btn.disabled, "5.10 DevineButton re-enabled after _resolve (year 906 >= 906 gate)")

	# Clean exit
	if _failures == 0:
		print("TURNREPORT_RUNTIME_PASS")
		get_tree().quit(0)
	else:
		print("TURNREPORT_RUNTIME_FAIL: %d failure(s)" % _failures)
		get_tree().quit(1)