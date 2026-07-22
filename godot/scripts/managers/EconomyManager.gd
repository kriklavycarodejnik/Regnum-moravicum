# scripts/managers/EconomyManager.gd
extends RefCounted

var game_state


func _init(state: RefCounted = null) -> void:
	if state != null:
		game_state = state


func process_economy() -> Dictionary:
	var report: Dictionary = {
		"type": "economy",
		"prosperity_growth": {},
		"upkeep": {},
		"production": {},
		"balance": {},
	}
	if game_state == null:
		return report
	if game_state.has_method("ensure_resources"):
		game_state.ensure_resources()

	var provinces: Dictionary = game_state.provinces
	var food_prod: int = 0
	var wood_prod: int = 0
	var stone_prod: int = 0
	var iron_prod: int = 0
	var gold_prod: int = 0

	for province_id in provinces.keys():
		var province_v = provinces[province_id]
		if typeof(province_v) != TYPE_DICTIONARY:
			continue
		var province: Dictionary = province_v
		if str(province.get("owner_faction", "")) != "moravia":
			continue
		var prosperity: float = float(province.get("prosperity", 50.0))
		prosperity = clampf(prosperity + 0.5, 0.0, 100.0)
		province["prosperity"] = prosperity
		report["prosperity_growth"][province_id] = prosperity
		var p_factor: float = prosperity / 100.0
		food_prod += int(8.0 * p_factor) + 2
		wood_prod += int(5.0 * p_factor) + 1
		stone_prod += int(3.0 * p_factor)
		iron_prod += int(2.0 * p_factor)
		gold_prod += int(4.0 * p_factor) + 1

	var total_upkeep: int = 0
	var nobles: Dictionary = game_state.nobles
	for noble_id in nobles.keys():
		var noble_v = nobles[noble_id]
		if typeof(noble_v) != TYPE_DICTIONARY:
			continue
		var noble: Dictionary = noble_v
		total_upkeep += int(noble.get("prestige", 10)) * 2

	var army_food: int = 0
	var armies: Dictionary = game_state.armies
	for aid in armies.keys():
		var army_v = armies[aid]
		if typeof(army_v) != TYPE_DICTIONARY:
			continue
		var army: Dictionary = army_v
		var fac: String = str(army.get("faction_id", army.get("owner", "")))
		if fac == "moravia" or fac == "":
			army_food += maxi(1, int(army.get("size", army.get("strength", 100))) / 50)

	var resources: Dictionary = game_state.resources
	resources["gold"] = int(resources.get("gold", 0)) + gold_prod - total_upkeep
	resources["food"] = int(resources.get("food", 0)) + food_prod - army_food
	resources["wood"] = int(resources.get("wood", 0)) + wood_prod
	resources["stone"] = int(resources.get("stone", 0)) + stone_prod
	resources["iron"] = int(resources.get("iron", 0)) + iron_prod
	for k in ["gold", "food", "wood", "stone", "iron", "prestige"]:
		resources[k] = int(resources.get(k, 0))
	game_state.resources = resources

	report["upkeep"] = {"nobles": total_upkeep, "army_food": army_food}
	report["production"] = {
		"gold": gold_prod,
		"food": food_prod,
		"wood": wood_prod,
		"stone": stone_prod,
		"iron": iron_prod,
	}
	report["balance"] = resources.duplicate(true)
	return report
