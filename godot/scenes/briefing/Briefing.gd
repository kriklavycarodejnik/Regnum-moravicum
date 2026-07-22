# scenes/briefing/Briefing.gd
# Prvý kontakt hráča: kto si, čo chceš, ako hrať (3 kroky).
extends Control

const _ThemeFactory = preload("res://assets/theme/regnum_theme_factory.gd")
const _Colors = preload("res://assets/theme/colors.gd")

@onready var start_btn: Button = $Margin/VBox/StartButton
@onready var back_btn: Button = $Margin/VBox/BackButton
@onready var art: TextureRect = $Margin/VBox/ArtRow/Art
@onready var body: RichTextLabel = $Margin/VBox/Body


func _ready() -> void:
	theme = _ThemeFactory.build()
	$Background.color = _Colors.BG_DARKER
	var cat = get_node_or_null("/root/ArtCatalog")
	if cat and art:
		var tex: Texture2D = cat.texture("mojmir_ii_master_portrait")
		if tex == null:
			tex = cat.texture("moravian_court_interior")
		if tex != null:
			art.texture = tex
	if body:
		body.clear()
		body.append_text("""[center][font_size=28][color=#C9A227]Tvoje poslanie[/color][/font_size][/center]

Si [b]Mojmír II.[/b], knieža [b]Veľkej Moravy[/b]. Rok je [color=#C9A227]902[/color].
Dynastia Mojmírovcov drží ríšu — ale Európa sa mení a z východu prichádzajú [b]Maďari[/b].

[b]Ako vyhrať[/b]
Preži s aspoň jednou župou a živou dynastiou do roku [color=#C9A227]1000[/color].

[b]Ako prehrať[/b]
Strata všetkých žúp · vymretie rodu · krach pokladnice.

[b]Ako hrať (3 kroky)[/b]
1. Na mape [b]klikni župu[/b] — vpravo uvidíš ilustráciu a stav.
2. Hlavné tlačidlo je [color=#C9A227][b]Ďalší mesiac[/b][/color] — posunie čas (ekonomika, AI, eventy).
3. Keď príde [b]udalosť[/b], vyber jednu z dvoch volieb.

[color=#7A6B55]Devín 907[/color] je historický scenár bitky (odporúčaný okolo roku 907), nie povinný každý ťah.
Záložky [b]Armády[/b] a [b]Diplomacia[/b] sú voliteľné nástroje medzi ťahmi.
""")
	start_btn.pressed.connect(_on_start)
	back_btn.pressed.connect(_on_back)


func _on_start() -> void:
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/MainMenu.tscn")
