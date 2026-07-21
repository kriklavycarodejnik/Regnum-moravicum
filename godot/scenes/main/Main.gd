# scenes/main/Main.gd
extends Control

@onready var year_label: Label = $UI/StatusBar/YearLabel
@onready var resources_label: Label = $UI/StatusBar/ResourcesLabel
@onready var chronicle_label: RichTextLabel = $UI/Chronicle
@onready var next_month_btn: Button = $UI/NextMonthButton
@onready var provinces_label: Label = $UI/ProvincesLabel
@onready var event_panel: PanelContainer = $UI/EventPanel
@onready var event_title: Label = $UI/EventPanel/EventVBox/EventTitle
@onready var event_body: Label = $UI/EventPanel/EventVBox/EventBody
@onready var choice_a_btn: Button = $UI/EventPanel/EventVBox/Choices/ChoiceA
@onready var choice_b_btn: Button = $UI/EventPanel/EventVBox/Choices/ChoiceB


func _ready() -> void:
	next_month_btn.pressed.connect(_on_next_month)
	choice_a_btn.pressed.connect(_on_choice_a)
	choice_b_btn.pressed.connect(_on_choice_b)
	event_panel.visible = false
	_refresh_ui()
	_append_chronicle("Kronika sa začína. Mojmír II. vládne Veľkej Morave.")


func _on_next_month() -> void:
	if GameManager.has_pending_event():
		_show_event(GameManager.get_pending_event())
		return

	var report: Dictionary = GameManager.process_next_month()
	_refresh_ui()
	if report.has("chronicle") and str(report["chronicle"]) != "":
		_append_chronicle("[%d/%02d] %s" % [
			report.get("year", 0),
			report.get("month", 0),
			report["chronicle"]
		])

	if GameManager.has_pending_event():
		_show_event(GameManager.get_pending_event())


func _show_event(ev: Variant) -> void:
	if ev == null or typeof(ev) != TYPE_DICTIONARY:
		return
	event_panel.visible = true
	next_month_btn.disabled = true
	event_title.text = str(ev.get("title", "Udalosť"))
	event_body.text = str(ev.get("body", ""))
	var choices: Array = ev.get("choices", [])
	if choices.size() >= 1:
		choice_a_btn.text = str(choices[0].get("label", "A"))
		choice_a_btn.set_meta("choice_id", str(choices[0].get("id", "")))
	if choices.size() >= 2:
		choice_b_btn.text = str(choices[1].get("label", "B"))
		choice_b_btn.set_meta("choice_id", str(choices[1].get("id", "")))


func _on_choice_a() -> void:
	_resolve(str(choice_a_btn.get_meta("choice_id", "")))


func _on_choice_b() -> void:
	_resolve(str(choice_b_btn.get_meta("choice_id", "")))


func _resolve(choice_id: String) -> void:
	var result: Dictionary = GameManager.resolve_event_choice(choice_id)
	event_panel.visible = false
	next_month_btn.disabled = false
	_refresh_ui()
	if result.get("ok", false) and result.has("chronicle"):
		_append_chronicle(str(result["chronicle"]))


func _refresh_ui() -> void:
	var s = GameManager.game_state
	year_label.text = "Rok %d · mesiac %d" % [s.year, s.month]
	resources_label.text = "Zlato: %d | Jedlo: %d | Drevo: %d | Prestíž: %d" % [
		s.resources.get("gold", 0),
		s.resources.get("food", 0),
		s.resources.get("wood", 0),
		s.resources.get("prestige", 0)
	]
	var edge_hint := 0
	for pid in s.provinces:
		var p = s.provinces[pid]
		if typeof(p) == TYPE_DICTIONARY:
			edge_hint += p.get("neighbors", []).size()
	provinces_label.text = "Župy: %d · susedstvá: %d" % [s.provinces.size(), edge_hint / 2]


func _append_chronicle(text: String) -> void:
	chronicle_label.append_text(text + "\n")
