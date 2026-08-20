# tools/screenshot_trace.gd
# Screenshot harness pre Regnum Moravicum vizuálnu QA.
#
# Spustenie (BEZ --headless — display-backed; headless nevytvára framebuffer,
# takže root.get_texture() vracia null a capture zlyhá):
#   bash tools/capture.sh
#   alebo priamo:
#   godot --disable-vsync -s res://tools/screenshot_trace.gd --quit-after 240
#
# Vygeneruje 7 PNG do godot/tools/screenshots/ (celá 10-minútová trasa):
#   01_MENU          — hlavné menu
#   02_BRIEFING      — poslanie po "Nová hra"
#   03_COACH_1_3     — coach krok 1/3 "Klikni na Nitru"
#   04_COACH_2_3     — coach krok 2/3 "poslanie" (po kliknutí na Nitru)
#   05_COACH_3_3     — coach krok 3/3 "Stlač Ďalší mesiac"
#   06_TURNREPORT    — mesačná správa po "Ďalší mesiac"
#   07_MAPA_PO_TAHU  — mapa po zatvorení TurnReportu a vyriešení udalosti
#
# extends SceneTree — nahrádza default MainLoop, takže:
#   - self.root = Window (Viewport); tex = root.get_texture()
#   - NEPOUŽÍVAŤ get_viewport() ani get_tree() — neexistujú v SceneTree
#   - quit() namiesto get_tree().quit()
#   - Autoloady (GameManager, ArtCatalog) sú dostupné cez root.get_node(...)

extends SceneTree

const OUTPUT_DIR := "res://tools/screenshots/"
const CAPTURE_W := 1280
const CAPTURE_H := 720

var captured_count := 0
var _main_node = null  # Main.tscn root


func _init() -> void:
	print("=== Regnum Moravicum — Screenshot Trace ===")
	print("Steps: 7 (MENU, BRIEFING, COACH_1_3, COACH_2_3, COACH_3_3, TURNREPORT, MAPA_PO_TAHU)")
	call_deferred("_run_trace")


func _process(_delta: float) -> bool:
	return false


# ─── Helper na prístup k autoloadom ───


func _gm() -> Node:
	"""Vráti GameManager autoload."""
	return root.get_node("GameManager")


func _gs():
	"""Vráti GameManager.game_state."""
	var gm: Node = _gm()
	if gm == null:
		return null
	return gm.game_state


# ─── Lifecycle ───


func _run_trace() -> void:
	captured_count = 0
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)

	# Pevná veľkosť okna + minimalizácia, aby render nerušil používateľa
	DisplayServer.window_set_size(Vector2i(CAPTURE_W, CAPTURE_H))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)

	await _step_menu()
	await _step_briefing()
	await _step_coach_1_3()
	await _step_coach_2_3()
	await _step_coach_3_3()
	await _step_turn_report()
	await _step_mapa_po_tahu()

	print("")
	print("=== Complete: %d/7 screenshots ===" % captured_count)
	if captured_count >= 7:
		quit(0)
	else:
		printerr("FAIL: Not all screenshots captured (%d/7)" % captured_count)
		quit(1)


# ─── Jednotlivé kroky ───


func _step_menu() -> void:
	print("--- Step 1/7: MENU ---")
	var menu = load("res://scenes/menu/MainMenu.tscn").instantiate()
	root.add_child(menu)
	await _wait_frames(3)
	await _capture_step("01_MENU")
	_clear_scene_children()


func _step_briefing() -> void:
	print("--- Step 2/7: BRIEFING (nová hra) ---")
	# "Nová hra" = GameManager.reset() → Briefing.tscn
	var gm: Node = _gm()
	if gm != null and gm.has_method("reset"):
		gm.reset()
	var briefing = load("res://scenes/briefing/Briefing.tscn").instantiate()
	root.add_child(briefing)
	await _wait_frames(3)
	await _capture_step("02_BRIEFING")
	_clear_scene_children()


func _step_coach_1_3() -> void:
	print("--- Step 3/7: COACH_1_3 (Klikni na Nitru) ---")
	_main_node = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(_main_node)
	await _wait_frames(3)
	_debug_coach_state("03_COACH_1_3")
	await _capture_step("03_COACH_1_3")


func _step_coach_2_3() -> void:
	print("--- Step 4/7: COACH_2_3 (klik na Nitru) ---")
	# Klik na Nitru = výber župy (vizual) + coach krok 1→2.
	# Voláme handler priamo (nie emit signálu): emit by spustil aj
	# _coach_on_province_selected → call_deferred("_show_coach_overlay"),
	# ktorý v -s SceneTree kontexte mešká o ~4-5 snímok a vytvorí stale
	# overlay, ktorý _coach_cleanup() (hľadá presné meno) už nezmaže.
	_main_node._on_province_selected("nitra")
	await _advance_coach(1)
	await _wait_frames(2)
	_debug_coach_state("04_COACH_2_3")
	await _capture_step("04_COACH_2_3")


func _step_coach_3_3() -> void:
	print("--- Step 5/7: COACH_3_3 (Rozumiem) ---")
	await _advance_coach(2)
	await _wait_frames(2)
	_debug_coach_state("05_COACH_3_3")
	await _capture_step("05_COACH_3_3")


func _step_turn_report() -> void:
	print("--- Step 6/7: TURNREPORT (Ďalší mesiac) ---")
	if _main_node.next_month_btn != null:
		_main_node.next_month_btn.pressed.emit()
		print("  Pressed 'Ďalší mesiac' — TurnReport by mal byť viditeľný")
	else:
		printerr("  WARN: next_month_btn missing — calling _on_next_month directly")
		_main_node._on_next_month()
	await _wait_frames(4)
	_debug_coach_state("06_TURNREPORT")
	await _capture_step("06_TURNREPORT")


func _step_mapa_po_tahu() -> void:
	print("--- Step 7/7: MAPA_PO_TAHU (dismiss TurnReport + udalosť) ---")
	# Zatvor TurnReport
	var tr = _main_node.turn_report
	if tr != null and is_instance_valid(tr) and tr.visible:
		_main_node._on_turn_report_dismissed()
		print("  Dismissed TurnReport")
	# Po prvom mesiaci sa zobrazí udalosť (Korunovácia) — vyrieš ju, aby
	# bola viditeľná mapa namiesto event panela.
	if _main_node.event_panel != null and _main_node.event_panel.visible:
		_main_node._on_choice_a()
		print("  Resolved event (choice A) — mapa by mala byť viditeľná")
	await _wait_frames(6)
	_debug_coach_state("07_MAPA_PO_TAHU")
	await _capture_step("07_MAPA_PO_TAHU")


# ─── Coach ───


func _advance_coach(step: int) -> void:
	"""Posunie coach na daný krok (ekvivalent handlera tlačidla)."""
	var gs = _gs()
	if gs == null:
		return
	gs.tutorial_step = step
	_main_node._coach_cleanup()
	# Počkať, kým queue_free odstráni starý overlay — inak add_child v
	# _show_coach_overlay narazí na name collision a premenuje nové uzly,
	# čo by neskôr zlomilo _coach_cleanup() (hľadá presné mená).
	await _wait_frames(2)
	_main_node._show_coach_overlay()


func _debug_coach_state(label: String) -> void:
	var gs = _gs()
	if gs == null:
		print("  [%s] no game_state" % label)
		return
	var overlay = _find_node("CoachOverlay", _main_node)
	var buttons = _find_node("CoachButtons", _main_node)
	var tr = _main_node.turn_report
	print("  [%s] step=%d done=%s overlay=%s buttons=%s turnreport=%s" % [
		label,
		int(gs.tutorial_step),
		str(gs.tutorial_done),
		str(overlay != null),
		str(buttons != null),
		str(tr != null and tr.visible),
	])
	# Vypíš reálne mená coach uzlov (na odhalenie name-collision premenovania)
	var coach_names: Array = []
	for child in _main_node.get_children():
		if "Coach" in child.name:
			coach_names.append(child.name)
	if not coach_names.is_empty():
		print("    coach nodes: %s" % str(coach_names))


func _dump_ui_state(label: String) -> void:
	"""Vypíše stav kľúčových UI uzlov presne v momente capture."""
	if _main_node == null or not is_instance_valid(_main_node):
		return
	var tr = _main_node.turn_report
	var ep = _main_node.event_panel
	print("  [%s] turn_report.visible=%s event_panel.visible=%s next_month.disabled=%s" % [
		label,
		str(tr != null and tr.visible),
		str(ep != null and ep.visible),
		str(_main_node.next_month_btn != null and _main_node.next_month_btn.disabled),
	])


# ─── Capture ───


func _capture_step(label: String) -> void:
	await _wait_frames(2)
	_dump_ui_state(label)

	var tex = root.get_texture()
	if tex == null:
		printerr("  WARN: get_texture null for '%s' (beží to bez --headless?)" % label)
		return

	var img = tex.get_image()
	if img == null:
		printerr("  WARN: get_image null for '%s'" % label)
		return

	var filename := "%s.png" % label
	var full_path := OUTPUT_DIR + filename

	var err = img.save_png(full_path)
	if err == OK:
		captured_count += 1
		print("  Saved: %s (%dx%d)" % [full_path, img.get_width(), img.get_height()])
	else:
		printerr("  Failed to save: %s (err=%d)" % [full_path, err])


# ─── Helpery ───


func _wait_frames(n: int) -> void:
	for i in range(n):
		await Engine.get_main_loop().process_frame


func _clear_scene_children() -> void:
	"""Odstráni všetky deti root okrem autoloadov (GameManager, ArtCatalog)."""
	for child in root.get_children():
		var n = child.name
		if n == "GameManager" or n == "ArtCatalog":
			continue
		child.queue_free()
	await Engine.get_main_loop().process_frame


func _find_node(name: String, parent: Node) -> Node:
	"""Rekurzívne hľadanie uzla podľa mena."""
	if parent == null:
		return null
	if parent.name == name:
		return parent
	for child in parent.get_children():
		var found = _find_node(name, child)
		if found != null:
			return found
	return null
