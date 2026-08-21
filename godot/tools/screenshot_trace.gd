# tools/screenshot_trace.gd
# Screenshot harness pre Regnum Moravicum vizuálnu QA.
# Spustenie (BEZ --headless — display-backed; headless nevytvára framebuffer,
# takže root.get_texture() vracia null a capture zlyhá):
#   bash tools/capture.sh
#   alebo priamo:
#   godot --disable-vsync -s res://tools/screenshot_trace.gd --quit-after 240
#
# Vygeneruje 7 PNG do godot/tools/screenshots/ (viz. karta t_ff5bbdd1):
#   01_MENU          — hlavné menu
#   02_BRIEFING      — poslanie po "Nová hra"
#   03_KLIK_NA_NITRO — klik na Nitru (panel výberu MUSÍ byť vyplnený)
#   04_TURNREPORT    — mesačná správa po "Ďalší mesiac"
#   05_EVENT_903     — event 903/01 (pápežské posolstvo) s voľbami
#   06_MAPA_906      — mapa v roku 906 s threat markermi a threat clockom
#   07_DEVIN_MODAL   — Devín prepare modal 907/01
#
# extends SceneTree — nahrádza default MainLoop, takže:
#   - self.root = Window (Viewport); tex = root.get_texture()
#   - NEPOUŽÍVAŤ get_viewport() ani get_tree() — neexistujú v SceneTree
#   - quit() namiesto get_tree().quit()
#   - Autoloady (GameManager, ArtCatalog) sú dostupné cez root.get_node(...)
#
extends SceneTree

# POZOR: res:// je v kanban worktree kópia repa — snímky by skončili vo worktree,
# ktorý sa po zlúčení pruneuje, a reviewer by ich nikdy nevidel. Preto absolútna
# cesta do hlavného repa. Prepísateľné cez REGNUM_SHOTS_DIR.
var OUTPUT_DIR: String = _resolve_output_dir()

static func _resolve_output_dir() -> String:
	var d: String = OS.get_environment("REGNUM_SHOTS_DIR")
	if d == "":
		d = "/Users/home/projects/regnum-moravicum-official/godot/tools/screenshots"
	return d.trim_suffix("/") + "/"

const CAPTURE_W := 1280
const CAPTURE_H := 720

var captured_count := 0
var _main_node = null  # Main.tscn root


func _gm() -> Node:
	"""Vráti GameManager autoload."""
	return root.get_node("GameManager")


func _init() -> void:
	print("=== Regnum Moravicum — Screenshot Trace === ")
	print("Steps: 7 (MENU, BRIEFING, KLIK_NA_NITRO, TURNREPORT, EVENT_903, MAPA_906, DEVIN_MODAL)")
	call_deferred("_run_trace")


func _process(_delta: float) -> bool:
	return false


# ─── Lifecycle ───


func _run_trace() -> void:
	captured_count = 0
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)

	# Pevná veľkosť okna + minimalizácia, aby render nerušil používateľa
	DisplayServer.window_set_size(Vector2i(CAPTURE_W, CAPTURE_H))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)

	await _a_step_menu()
	await _a_step_briefing()
	await _a_step_click_na_nitro()
	await _a_step_turn_report()
	await _a_step_event_903()
	await _a_step_mapa_906()
	await _a_step_devin_modal()

	print("")
	print("=== Complete: %d/7 screenshots ===" % captured_count)
	if captured_count >= 7:
		quit(0)
	else:
		printerr("FAIL: Not all screenshots captured (%d/7)" % captured_count)
		quit(1)


# ─── Individual steps ───


func _a_step_menu() -> void:
	print("--- Step 1/7: MENU ---")
	var menu = load("res://scenes/menu/MainMenu.tscn").instantiate()
	root.add_child(menu)
	await _wait_frames(3)
	await _capture_step("01_MENU")
	_clear_scene_children()


func _a_step_briefing() -> void:
	print("--- Step 2/7: BRIEFING (nová hra) ---")
	var briefing = load("res://scenes/briefing/Briefing.tscn").instantiate()
	root.add_child(briefing)
	await _wait_frames(3)
	await _capture_step("02_BRIEFING")
	_clear_scene_children()


func _a_step_click_na_nitro() -> void:
	print("--- Step 3/7: KLIK_NA_NITRO (panel výberu vyplnený) ---")
	_main_node = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(_main_node)
	await _wait_frames(3)
	_main_node._on_province_selected("nitra")
	await _wait_frames(2)
	var sl = _main_node.selection_label
	if sl == null:
		printerr("  FAIL: selection_label missing — panel výberu neexistuje")
	elif str(sl.text).length() < 10:
		printerr("  FAIL: selection_label prázdny (%s) — panel výberu NIE JE vyplnený" % str(sl.text))
	else:
		print("  OK: selection_label vyplnený: %s" % str(sl.text))
	await _capture_step("03_KLIK_NA_NITRO")
	# Posuň coach na krok 3/3 ("Stlač Ďalší mesiac") — inak _on_next_month
	# nevidí tutorial_step==2 a nedokončí tutoriál (overlay by ostal aj na
	# neskorších snímkach).
	await _advance_coach(2)
	await _wait_frames(2)


func _a_step_turn_report() -> void:
	print("--- Step 4/7: TURNREPORT (Ďalší mesiac) ---")
	if _main_node.next_month_btn != null:
		_main_node.next_month_btn.pressed.emit()
		print("  Pressed 'Ďalší mesiac' — čakám na TurnReport")
	else:
		printerr("  WARN: next_month_btn missing — calling _on_next_month directly")
		_main_node._on_next_month()

	# Čakáme max 60 frames, kým TurnReport nie je viditeľný a event_panel je skrytý
	var timeout := 60
	while timeout > 0:
		var tr_visible: bool = _main_node.turn_report != null and _main_node.turn_report.visible
		var ep_hidden: bool = _main_node.event_panel == null or not _main_node.event_panel.visible
		if tr_visible and ep_hidden:
			print("  TurnReport viditeľný (event_panel skrytý) — zachytávam")
			await _capture_step("04_TURNREPORT")
			return
		await Engine.get_main_loop().process_frame
		timeout -= 1

	printerr("FAIL: TurnReport sa nezobrazil do 60 frames")
	printerr("  turn_report=%s event_panel=%s" % [
		str(_main_node.turn_report != null and _main_node.turn_report.visible),
		str(_main_node.event_panel != null and _main_node.event_panel.visible),
	])
	quit(1)


func _a_step_event_903() -> void:
	print("--- Step 5/7: EVENT_903 (pápežské posolstvo s voľbami) ---")

	# STEP A: Hide overlays that eat vertical space (chronicle, notification, selection,
	# turn report). EventPanel je posledný (ne-expand) child MainColumn, takže obsah nad
	# ním (MapView min 280 + ChroniclePanel min 70 + chrome) tlačí panel pod 720px viewport.
	var _chron_vis := false
	var _chron_node := _find_node("ChroniclePanel", _main_node) if _main_node != null else null
	if _chron_node != null and is_instance_valid(_chron_node):
		_chron_vis = _chron_node.visible
		_chron_node.visible = false
	var _notif_vis := false
	if _main_node.notification_feed != null and is_instance_valid(_main_node.notification_feed):
		_notif_vis = _main_node.notification_feed.visible
		_main_node.notification_feed.visible = false
	var _sel_vis := false
	if _main_node.selection_label != null and is_instance_valid(_main_node.selection_label):
		_sel_vis = _main_node.selection_label.visible
		_main_node.selection_label.visible = false
	if _main_node.turn_report != null and is_instance_valid(_main_node.turn_report):
		_main_node.turn_report.hide()

	# STEP B: Posun hry do roku 903/01, aby sa vygeneroval historický event
	# hist_papal_legation_903 (Pápežské posolstvo).
	var gs = _gm().game_state if _gm() != null else null
	if gs != null:
		gs.year = 903
		gs.month = 1
		# Vyčisti pending event z predošlých tikov (inak process_events vráti
		# starý pending namiesto generovania historického eventu 903/01)
		gs.pending_event = null
		# Reset triggered_events + cooldowns to force re-queue
		gs.triggered_events = []
		gs.event_cooldowns = {}
		print("  GameState posunutý na %d/%02d" % [gs.year, gs.month])

	# Re-initialize EventManager to pick up the event
	var gm = _gm()
	if gm != null and gm.event_manager != null:
		gm.event_manager._loaded = false
		gm.event_manager._load_catalog()
		gm.event_manager.process_events()
	await _wait_frames(4)

	# Force-show event panel if still hidden
	if _main_node.event_panel == null or not _main_node.event_panel.visible:
		if gm != null and gm.has_pending_event():
			var ev = gm.get_pending_event()
			if ev != null:
				_main_node._show_event(ev)
				await _wait_frames(3)

	# Refresh visible UI and settle layout
	if _main_node != null and is_instance_valid(_main_node):
		if _main_node.has_method("_refresh_ui"):
			_main_node._refresh_ui()
		await _wait_frames(3)

	# STEP C: Grow the SOURCE viewport until the event panel AND every visible choice
	# button fit entirely inside it. At 720px the panel overflows below the screen edge,
	# so those pixels are lost before _capture_step() resizes — resize can't recover
	# already-clipped content. Only after the panel is fully inside the framebuffer do we
	# capture; _capture_step() then deterministically shrinks to exactly 1280x720.
	await _grow_viewport_to_fit_event(40)

	# STEP D: Assert date + title + geometry (panel/choices fully inside viewport).
	# quit(1) on any mismatch so a truncated panel fails the capture loudly.
	_assert_903_event_state()

	_dump_ui_state("05_EVENT_903")
	await _capture_step("05_EVENT_903")

	# STEP E: Restore overlays + 720p viewport for subsequent steps
	if _chron_node != null and is_instance_valid(_chron_node):
		_chron_node.visible = _chron_vis
	if _main_node.notification_feed != null and is_instance_valid(_main_node.notification_feed):
		_main_node.notification_feed.visible = _notif_vis
	if _main_node.selection_label != null and is_instance_valid(_main_node.selection_label):
		_main_node.selection_label.visible = _sel_vis

	DisplayServer.window_set_size(Vector2i(CAPTURE_W, CAPTURE_H))
	await _wait_frames(2)

	# Resolve event choice so subsequent steps start clean
	if _main_node.event_panel != null and _main_node.event_panel.visible:
		_main_node._on_choice_a()
		await _wait_frames(2)


func _a_step_mapa_906() -> void:
	print("--- Step 6/7: MAPA_906 (threat markery + threat clock) ---")
	var gs = _gm().game_state if _gm() != null else null
	if gs != null:
		gs.year = 906
		gs.month = 1
		print("  GameState posunutý na %d/%02d" % [gs.year, gs.month])
	if _main_node.has_method("_on_choice_a"):
		_main_node._on_choice_a()
	if _main_node.has_method("_refresh_ui"):
		_main_node._refresh_ui()
	await _wait_frames(6)
	await _capture_step("06_MAPA_906")


func _a_step_devin_modal() -> void:
	print("--- Step 7/7: DEVIN_MODAL (907/01 prepare) ---")
	var gs = _gm().game_state if _gm() != null else null
	if gs != null:
		gs.year = 907
		gs.month = 1
		print("  GameState posunutý na %d/%02d" % [gs.year, gs.month])
	if _main_node.has_method("_refresh_ui"):
		_main_node._refresh_ui()
	if _main_node.has_method("_show_devin_modal"):
		_main_node._show_devin_modal("prepare")
	await _wait_frames(6)
	await _capture_step("07_DEVIN_MODAL")


# ─── Coach ───


func _advance_coach(step: int) -> void:
	"""Posunie coach na daný krok (ekvivalent handlera tlačidla)."""
	var gs = _gm().game_state if _gm() != null else null
	if gs != null:
		gs.tutorial_step = step
	var overlay = _find_node("CoachOverlay", _main_node)
	var buttons = _find_node("CoachButtons", _main_node)
	print("  Coach step: %d, overlay=%s, buttons=%s" % [step, str(overlay != null), str(buttons != null)])
	# Kľúčové: najprv cleanup starého overlayu — inak add_child v
	# _show_coach_overlay narazí na name collision a premenuje nové uzly,
	# čo by neskôr zlomilo _coach_cleanup() (hľadá presné mená).
	if _main_node.has_method("_coach_cleanup"):
		_main_node._coach_cleanup()
	await _wait_frames(2)
	_main_node._show_coach_overlay()


# ─── Helpery ───


func _assert_903_event_state() -> void:
	"""Refresh UI and assert 903/01 date + Pápežské posolstvo title."""
	if _main_node == null or not is_instance_valid(_main_node):
		printerr("  FAIL: _main_node is null — cannot assert event state")
		quit(1)

	# Assert: status bar shows 903/01
	var sb = _main_node.status_bar
	if sb == null:
		printerr("  FAIL: status_bar is null in _main_node")
		quit(1)
	var yl = _find_node("YearLabel", sb)
	if yl == null or not (yl is Label):
		printerr("  FAIL: YearLabel not found in status_bar")
		quit(1)
	var date_text: String = yl.text
	print("  StatusBar date: '%s'" % date_text)
	if date_text.find("903") == -1:
		printerr("  FAIL: StatusBar date '%s' chýba '903'" % date_text)
		quit(1)
	if date_text.find("mesiac 1") == -1 and date_text.find("1") == -1:
		printerr("  FAIL: StatusBar date '%s' chýba mesiac 1" % date_text)
		quit(1)
	print("  OK: StatusBar date matches 903/01")

	# Assert: event title shows "Pápežské posolstvo"
	var et = _main_node.event_title
	if et == null:
		printerr("  FAIL: event_title is null in _main_node")
		quit(1)
	var title_text: String = et.text
	print("  Event title: '%s'" % title_text)
	if title_text.find("Pápež") == -1:
		printerr("  FAIL: Event title is '%s', expected obsahovať 'Pápežské posolstvo'" % title_text)
		quit(1)
	print("  OK: Event title matches 'Pápežské posolstvo'")

	# Assert: event panel + every visible choice button are visible, have non-empty text,
	# and their bottom edge (get_global_rect().end.y) is within the SOURCE viewport.
	var vs := root.size
	var ep = _main_node.event_panel
	if ep == null or not is_instance_valid(ep) or not ep.visible:
		printerr("  FAIL: event_panel nie je viditeľný")
		quit(1)
	var ep_end: float = ep.get_global_rect().end.y
	print("  event_panel end.y=%.0f (viewport h=%d)" % [ep_end, vs.y])
	if ep_end > vs.y:
		printerr("  FAIL: event_panel presahuje viewport (end.y=%.0f > %d)" % [ep_end, vs.y])
		quit(1)

	# Tento event má presne 2 voľby (A/B) — obe musia byť viditeľné.
	var a_vis: bool = _main_node.choice_a_btn != null and _main_node.choice_a_btn.visible
	var b_vis: bool = _main_node.choice_b_btn != null and _main_node.choice_b_btn.visible
	if not a_vis or not b_vis:
		printerr("  FAIL: ChoiceA/ChoiceB nie sú viditeľné (A=%s B=%s)" % [str(a_vis), str(b_vis)])
		quit(1)

	for btn_name in ["choice_a_btn", "choice_b_btn", "choice_c_btn"]:
		var b = _main_node.get(btn_name)
		if b == null or not is_instance_valid(b):
			printerr("  FAIL: chýba %s" % btn_name)
			quit(1)
		if not b.visible:
			continue  # nie je súčasťou tohto eventu (napr. ChoiceC pri 2-voľbovom)
		var btn_text: String = str(b.text).strip_edges()
		if btn_text == "":
			printerr("  FAIL: %s má prázdny text" % btn_name)
			quit(1)
		var bend: float = b.get_global_rect().end.y
		if bend > vs.y:
			printerr("  FAIL: %s presahuje viewport (end.y=%.0f > %d)" % [btn_name, bend, vs.y])
			quit(1)
		print("  OK: %s visible, text='%s', end.y=%.0f" % [btn_name, btn_text, bend])


func _event_visual_bottom() -> float:
	"""Vráti najnižší spodný okraj event panela + viditeľných volieb (0.0 ak panel chýba)."""
	var bottom := 0.0
	if _main_node == null or not is_instance_valid(_main_node):
		return 0.0
	if _main_node.event_panel != null and is_instance_valid(_main_node.event_panel) and _main_node.event_panel.visible:
		bottom = _main_node.event_panel.get_global_rect().end.y
	for btn_name in ["choice_a_btn", "choice_b_btn", "choice_c_btn"]:
		var b = _main_node.get(btn_name)
		if b != null and is_instance_valid(b) and b.visible:
			bottom = maxf(bottom, b.get_global_rect().end.y)
	return bottom


func _grow_viewport_to_fit_event(margin: int) -> void:
	"""Zväčší SOURCE viewport, kým event panel + všetky voľby nie sú celé vo viewporte.

	EventPanel je posledný ne-expand child MainColumn, takže pri príliš nízkom viewporte
	je odrezaný pod spodným okrajom (get_global_rect().end.y > viewport). Meriame prirodzený
	spodný okraj, kým je panel odrezaný, a naraz zväčšíme viewport na tento okraj + margin.
	Po zväčšení sa panel usadí na spodnom okraji a celý sa zmestí.
	"""
	for _i in range(8):
		await _wait_frames(2)
		var bottom := _event_visual_bottom()
		if bottom <= 0.0:
			return  # žiadny event panel
		var vs := root.size
		if bottom <= vs.y:
			return  # už sa zmestí
		var new_h := int(bottom) + margin
		print("  Growing viewport %dx%d -> %dx%d (panel bottom %.0f)" % [vs.x, vs.y, CAPTURE_W, new_h, bottom])
		DisplayServer.window_set_size(Vector2i(CAPTURE_W, new_h))
	await _wait_frames(2)


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


# ─── Capture ───


func _capture_step(label: String) -> void:
	await _wait_frames(2)

	var tex = root.get_texture()
	if tex == null:
		printerr("  WARN: get_texture null for '%s' (beží to bez --headless?)" % label)
		return

	var img = tex.get_image()
	if img == null:
		printerr("  WARN: get_image null for '%s'" % label)
		return

	# Resize to canonical 1280x720 if captured at different dimensions
	# (e.g. 05_EVENT_903 is captured at 1280x960 to fit all choices)
	if img.get_width() != CAPTURE_W or img.get_height() != CAPTURE_H:
		print("  Resizing %dx%d -> %dx%d for '%s'" % [img.get_width(), img.get_height(), CAPTURE_W, CAPTURE_H, label])
		img.resize(CAPTURE_W, CAPTURE_H, Image.INTERPOLATE_LANCZOS)

	var filename := "%s.png" % label
	var full_path := OUTPUT_DIR + filename

	var err = img.save_png(full_path)
	if err == OK:
		captured_count += 1
		print("  Saved: %s (%dx%d)" % [full_path, img.get_width(), img.get_height()])
	else:
		printerr("  Failed to save: %s (err=%d)" % [full_path, err])


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
	# Geometria event panela + volieb (diagnostika orezania)
	var vs := root.size
	print("  [%s] viewport=%dx%d" % [label, vs.x, vs.y])
	if ep != null and is_instance_valid(ep) and ep.visible:
		var r: Rect2 = ep.get_global_rect()
		print("  [%s] event_panel rect=%s (end.y=%.0f, inside=%s)" % [label, r, r.end.y, str(r.end.y <= vs.y)])
	for btn_name in ["choice_a_btn", "choice_b_btn", "choice_c_btn"]:
		var b = _main_node.get(btn_name)
		if b != null and is_instance_valid(b) and b.visible:
			var br: Rect2 = b.get_global_rect()
			print("  [%s] %s rect=%s (end.y=%.0f, inside=%s)" % [label, btn_name, br, br.end.y, str(br.end.y <= vs.y)])


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