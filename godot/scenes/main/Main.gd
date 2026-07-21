# scenes/main/Main.gd
extends Control

@onready var year_label: Label = $UI/StatusBar/YearLabel
@onready var resources_label: Label = $UI/StatusBar/ResourcesLabel
@onready var chronicle_label: RichTextLabel = $UI/Chronicle
@onready var next_month_btn: Button = $UI/NextMonthButton
@onready var provinces_label: Label = $UI/ProvincesLabel


func _ready() -> void:
	next_month_btn.pressed.connect(_on_next_month)
	_refresh_ui()
	_append_chronicle("Kronika sa začína. Mojmír II. vládne Veľkej Morave.")


func _on_next_month() -> void:
	var report: Dictionary = GameManager.process_next_month()
	_refresh_ui()
	if report.has("chronicle") and str(report["chronicle"]) != "":
		_append_chronicle("[%d/%02d] %s" % [
			report.get("year", 0),
			report.get("month", 0),
			report["chronicle"]
		])


func _refresh_ui() -> void:
	var s = GameManager.game_state
	year_label.text = "Rok %d · mesiac %d" % [s.year, s.month]
	resources_label.text = "Zlato: %d | Jedlo: %d | Prestíž: %d" % [
		s.resources.get("gold", 0),
		s.resources.get("food", 0),
		s.resources.get("prestige", 0)
	]
	provinces_label.text = "Župy: %d" % s.provinces.size()


func _append_chronicle(text: String) -> void:
	chronicle_label.append_text(text + "\n")
