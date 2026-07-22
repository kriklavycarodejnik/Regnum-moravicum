# scripts/managers/WarManager.gd
...

func process_siege(army_id: String, province_id: String) -> Dictionary:
	if not game_state.armies.has(army_id) or not game_state.provinces.has(province_id):
		return {"success": false, "error": "invalid_army_or_province"}
	
	var army = game_state.armies[army_id]
	var province = game_state.provinces[province_id]
	
	# Check if province is already owned by attacker
	if province.get("owner_faction", "") == army.get("faction_id", ""):
		return {"success": true, "progress": 100}
	
	# Check if army is adjacent
	if not are_adjacent(army.get("province_id", ""), province_id):
		return {"success": false, "error": "not_adjacent"}
	
	# Siege progress (simplified)
	var siege_progress = province.get("siege_progress", 0) + 10
	province["siege_progress"] = siege_progress
	game_state.provinces[province_id] = province
	
	if siege_progress >= 100:
		province["owner_faction"] = army.get("faction_id", "")
		province["siege_progress"] = 0
		game_state.provinces[province_id] = province
		return {"success": true, "progress": 100}
	else:
		return {"success": false, "progress": siege_progress}