extends Node

var failures: int = 0

func check_ok(condition: bool, label: String) -> void:
	if condition:
		print("RUNTIME_PASS: " + label)
	else:
		push_error("RUNTIME_FAIL: " + label)
		failures += 1

func count_named(node: Node, wanted: String) -> int:
	var count: int = 1 if node.name == wanted else 0
	for child in node.get_children():
		count += count_named(child, wanted)
	return count

func find_button(node: Node) -> Button:
	if node is Button:
		return node as Button
	for child in node.get_children():
		var found: Button = find_button(child)
		if found != null:
			return found
	return null

func dump_tree(node: Node, depth: int = 0) -> void:
	print("TREE ", "  ".repeat(depth), node.name, " ", node.get_class())
	for child in node.get_children():
		dump_tree(child, depth + 1)

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	await get_tree().process_frame
	var main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var gs = GameManager.game_state
	gs.year = 906
	gs.month = 6
	gs.army_wizard_done = false
	var created: Dictionary = GameManager.army_manager.create_army("review_wizard_army", "moravia_levy", "bratislava")
	check_ok(bool(created.get("ok", false)), "vytvorenie armády")
	main._try_show_army_wizard()
	await get_tree().process_frame
	check_ok(count_named(main, "ArmyWizardOverlay") == 1 and count_named(main, "ArmyWizardButtons") == 1, "W1 otvorí práve jeden wizard")
	main.army_ui._on_army_selected("review_wizard_army")
	await get_tree().process_frame
	check_ok(main._army_wizard_step == 1, "W1 výber armády → W2")
	main.army_ui._on_move_button_pressed()
	await get_tree().process_frame
	check_ok(main._army_wizard_step == 2, "W2 otvorenie presunu → W3")
	main._on_army_wizard_commander_confirmed()
	await get_tree().process_frame
	check_ok(main._army_wizard_step == 3, "W3 potvrdenie veliteľa → W4")
	main.army_ui._on_target_province_selected("review_wizard_army", "nitra")
	await get_tree().process_frame
	check_ok(gs.army_wizard_done == false and main._army_wizard_step == 3, "nesprávny cieľ neposunie W4")
	GameManager.army_manager.process_armies()
	main.army_ui._on_target_province_selected("review_wizard_army", "devin")
	await get_tree().process_frame
	check_ok(gs.army_wizard_done == true, "úspešný presun správnej armády k Devínu dokončí wizard")
	check_ok(count_named(main, "ArmyWizardOverlay") == 0 and count_named(main, "ArmyWizardButtons") == 0, "dokončenie odstráni wizard")
	gs.army_wizard_done = false
	main._army_wizard_overlay_active = false
	main.notification_feed.push_action("Pošli armádu k Devínu", "army_wizard")
	await get_tree().process_frame
	var action_button: Button = find_button(main.notification_feed)
	check_ok(action_button != null, "akčná notifikácia vytvorí tlačidlo")
	if action_button != null:
		action_button.pressed.emit()
	await get_tree().process_frame
	check_ok(count_named(main, "ArmyWizardOverlay") == 1 and count_named(main, "ArmyWizardButtons") == 1, "klik notifikácie vytvorí iba jeden wizard")
	gs.army_wizard_done = true
	main._army_wizard_overlay_active = false
	main._army_wizard_cleanup()
	await get_tree().process_frame
	check_ok(count_named(main, "ArmyWizardOverlay") == 0, "done guard po opakovanom otvorení neukáže overlay")
	print("RUNTIME_RESULT failures=%d" % failures)
	if failures == 0:
		print("ARMY_WIZARD_RUNTIME_PASS")
		get_tree().quit(0)
	else:
		print("ARMY_WIZARD_RUNTIME_FAIL")
		get_tree().quit(1)

func _exit_tree() -> void:
	pass
