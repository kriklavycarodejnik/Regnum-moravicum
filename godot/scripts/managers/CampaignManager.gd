# scripts/managers/CampaignManager.gd
class_name CampaignManager
extends RefCounted

const SUPPLY_RANGE := 3  # Max provinces from supply source
const ATTRITION_RATE := 0.05  # 5% size loss per turn if out of supply

var game_state
var war_manager
var diplomacy_manager
var army_manager
var rng


func _init(state = null, war_mgr = null, dip_mgr = null, rng_ref = null, arm_mgr = null) -> void:
	if state != null:
		game_state = state
	if war_mgr != null:
		war_manager = war_mgr
	if dip_mgr != null:
		diplomacy_manager = dip_mgr
	if rng_ref != null:
		rng = rng_ref
	if arm_mgr != null:
		army_manager = arm_mgr


func process_campaign() -> Dictionary:
	var report := {"type": "campaign", "events": []}
	
	# Process player armies
	for army_id in game_state.armies:
		var army = game_state.armies[army_id]
		if army.get("faction_id", "") == "moravia":
			_process_player_army(army_id, army, report)
	
	# Process AI factions (Hungary, Franks)
	_process_ai_faction("hungary", report)
	_process_ai_faction("franks", report)
	
	return report


func _process_player_army(army_id: String, army: Dictionary, report: Dictionary) -> void:
	# Check supply
	if not _is_in_supply(army):
		var attrition = int(army.get("size", 0) * ATTRITION_RATE)
		army["size"] = max(army.get("size", 0) - attrition, 10)  # Minimum 10 troops
		report.events.append({
			"type": "attrition",
			"army_id": army_id,
			"size_loss": attrition,
			"reason": "out_of_supply"
		})
	
	# Process sieges
	if army.get("besieging", "") != "":
		var siege_result = war_manager.process_siege(army_id, army["besieging"])
		if siege_result.get("success", false):
			report.events.append({
				"type": "siege_success",
				"army_id": army_id,
				"province_id": army["besieging"]
			})
			army["besieging"] = ""
		else:
			report.events.append({
				"type": "siege_progress",
				"army_id": army_id,
				"province_id": army["besieging"],
				"progress": siege_result.get("progress", 0)
			})


func _process_ai_faction(faction_id: String, report: Dictionary) -> void:
	# Simple AI: expand towards targets
	var targets = {
		"hungary": ["pannonia", "transylvania", "banat"],
		"franks": ["bavaria", "saxony", "thuringia"]
	}
	
	for army_id in game_state.armies:
		var army = game_state.armies[army_id]
		if army.get("faction_id", "") == faction_id:
			# Check if already besieging
			if army.get("besieging", "") != "":
				continue
			
			# Find target province
			var target_province = ""
			for province_id in targets.get(faction_id, []):
				if game_state.provinces.has(province_id) and game_state.provinces[province_id].get("owner_faction", "") != faction_id:
					target_province = province_id
					break
			
			if target_province == "":
				continue
			
			# Move towards target
			var path = _find_path(army.get("province_id", ""), target_province)
			if path.size() > 1:
				var next_province = path[1]
				var move_result = army_manager.move_army(army_id, next_province)
				if move_result.get("ok", false):
					report.events.append({
						"type": "ai_movement",
						"army_id": army_id,
						"from": army.get("province_id", ""),
						"to": next_province,
						"faction_id": faction_id
					})
					army["province_id"] = next_province
				else:
					# Start siege if adjacent
					if war_manager.are_adjacent(army.get("province_id", ""), target_province):
						army["besieging"] = target_province
						report.events.append({
							"type": "ai_siege_start",
							"army_id": army_id,
							"province_id": target_province,
							"faction_id": faction_id
						})


func _is_in_supply(army: Dictionary) -> bool:
	var province_id = army.get("province_id", "")
	var province = game_state.provinces.get(province_id, {})
	var owner_faction = province.get("owner_faction", "")
	
	# Check if in friendly territory
	if owner_faction == army.get("faction_id", ""):
		return true
	
	# Check supply range
	var visited = []
	var queue = [province_id]
	var distance = 0
	
	while queue.size() > 0 and distance <= SUPPLY_RANGE:
		var current = queue.pop_front()
		if visited.has(current):
			continue
		visited.append(current)
		
		var current_province = game_state.provinces.get(current, {})
		if current_province.get("owner_faction", "") == army.get("faction_id", ""):
			return true
		
		for neighbor in current_province.get("neighbors", []):
			if not visited.has(neighbor):
				queue.append(neighbor)
			distance += 1
	
	return false


func _find_path(start: String, end: String) -> Array:
	# Simple BFS pathfinding
	var visited = []
	var queue = [[start]]
	
	while queue.size() > 0:
		var path = queue.pop_front()
		var current = path[-1]
		
		if current == end:
			return path
		
		if visited.has(current):
			continue
		visited.append(current)
		
		var neighbors = game_state.provinces.get(current, {}).get("neighbors", [])
		for neighbor in neighbors:
			var new_path = path.duplicate(true)
			new_path.append(neighbor)
			queue.append(new_path)
	
	return []