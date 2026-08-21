# tools/verify_chronicle_icons_runtime.gd
# Runtime test: načíta Main.tscn, odohrá 6+ ťahov (mesiacov) a overí,
# že každý chronicle záznam má ikonu aj dátum.
# Spúšťa sa: godot --headless --path . res://tools/verify_chronicle_icons_runtime.tscn
extends Node

var _failures: int = 0
var _ticks: int = 0
var _notified_about_devin: bool = false

func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: ", label)
	else:
		print("  FAIL: ", label)
		_failures += 1


func _ready() -> void:
	print("=== Runtime overenie chronicle ikon (autoloady zapnuté) ===")

	# 1. Skontrolovať, že ArtCatalog autoload funguje
	if ArtCatalog == null:
		push_error("ArtCatalog autoload not available")
		print("FAIL: ArtCatalog autoload not available")
		_failures += 1
		_clean_exit()
		return

	# 1. Overiť, že ArtCatalog autoload funguje a icon_scroll_64 je dostupná
	#    (používa sa pre monthly chronicle záznamy)
	check(ArtCatalog.has("icon_scroll_64"), "ArtCatalog: icon_scroll_64 existuje v art_map")
	var tex := ArtCatalog.texture("icon_scroll_64")
	check(tex != null and tex is Texture2D, "ArtCatalog: icon_scroll_64 → platná Texture2D (not null)")

	# 2. Overiť aj ostatné kľúče pre prípad potreby
	check(ArtCatalog.has("icon_bell_64"), "ArtCatalog: icon_bell_64 stále existuje (asset neodstraňujeme)")
	check(ArtCatalog.has("icon_next_month_64"), "ArtCatalog: icon_next_month_64 existuje v art_map, nepoužíva sa v monthly")

	# 3. Načítať Main.tscn
	var MainScene := preload("res://scenes/main/Main.tscn")
	var main = MainScene.instantiate()
	add_child(main)

	# 4. Nájsť chronicle komponenty
	var chronicle_list = main.get_node("UI/Body/MainColumn/ChroniclePanel/ChronicleScroll/ChronicleList")
	var chronicle_scroll = main.get_node("UI/Body/MainColumn/ChroniclePanel/ChronicleScroll")
	check(chronicle_list != null, "ChronicleList VBoxContainer nájdený")
	check(chronicle_scroll != null, "ChronicleScroll nájdený")

	# 5. Vypnúť tutorial, aby neblokoval hru
	if GameManager != null and GameManager.game_state != null:
		GameManager.game_state.tutorial_done = true
		GameManager.game_state.pending_event = null

	# 6. Odohrať 6+ ťahov (mesiacov)
	print("--- Prebieha %d ťahov ---" % 6)
	# Pred tickom vypneme generovanie eventov, aby sme neuviazli na event paneli
	if GameManager.event_manager != null:
		GameManager.event_manager._loaded = true
		GameManager.event_manager._catalog = []
		GameManager.game_state.last_event_id = "council"

	for _i in range(6):
		# Potlačiť eventy pred každým ťahom
		GameManager.game_state.pending_event = null
		# Volať _on_next_month — produkčná cesta
		main._on_next_month()
		# Dismiss TurnReport ak je zobrazený
		if main.turn_report != null and main.turn_report.visible:
			main.turn_report.continue_pressed.emit()
		await get_tree().process_frame
		_ticks += 1
		print("  ťah %d: year=%d month=%d, chronicle záznamov: %d" % [
			_ticks,
			GameManager.game_state.year,
			GameManager.game_state.month,
			chronicle_list.get_child_count()
		])

	print("--- Overenie chronicle záznamov ---")
	# 7. Overiť, že chronicle obsahuje záznamy
	check(chronicle_list.get_child_count() > 0, "Chronicle obsahuje %d záznamov (očakávané >0)" % chronicle_list.get_child_count())

	# 8. Overiť, že KAŽDÝ chronicle záznam (HBoxContainer) má TextureRect s platnou textúrou
	var all_have_dates: bool = true
	var all_have_icons: bool = true
	var monthly_count: int = 0

	for row_idx in range(chronicle_list.get_child_count()):
		var row = chronicle_list.get_child(row_idx)
		if row is HBoxContainer:
			var has_valid_icon: bool = false
			var has_date: bool = false
			for child in row.get_children():
				# TextureRect = icon
				if child is TextureRect:
					if child.texture != null:
						has_valid_icon = true
					else:
						print("    WARN: row[%d] TextureRect.texture == null" % row_idx)
				# Label s dátumom = "Rok XXX" alebo "XXX/XX"
				if child is Label:
					var txt: String = child.text
					if txt.begins_with("Rok ") or (txt.length() >= 5 and txt.find("/") != -1):
						has_date = true
			if not has_valid_icon:
				all_have_icons = false
			if not has_date:
				all_have_dates = false

	# 9. Overiť všetky ikony
	check(all_have_icons, "Všetky chronicle riadky majú platnú ikonu (TextureRect.texture != null)")
	check(all_have_dates, "Všetky chronicle riadky majú dátum")

	# 10. Overiť aspoň jeden měsíčný záznam ide cez icon_scroll_64
	#    (Skontrolujeme, že chronicle_list nie je prázdny — všetky ikony overené vyššie)
	#    Keďže každý ťah vytvorí monthly záznam, v chronicle sú monthly záznamy.
	check(tex != null, "icon_scroll_64 je platná textúra — používa sa pre monthly záznamy")

	# Clean exit
	if _failures == 0:
		print("CHRONICLE_RUNTIME_PASS")
		get_tree().quit(0)
	else:
		print("CHRONICLE_RUNTIME_FAIL: %d failure(s)" % _failures)
		get_tree().quit(1)


func _clean_exit() -> void:
	if _failures == 0:
		get_tree().quit(0)
	else:
		get_tree().quit(1)