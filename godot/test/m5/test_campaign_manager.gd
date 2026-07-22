# test/m5/test_campaign_manager.gd
extends "res://test/test_base.gd"


func test_campaign_determinism():
	var w1 = _make_world(42)
	var w2 = _make_world(42)
	
	# Process campaign twice with same seed
	var c1 = w1.campaign.process_campaign()
	var c2 = w2.campaign.process_campaign()
	
	# Compare events
	assert_eq(c1, c2, "Campaign AI nie je deterministická!")


func test_hungarian_expansion():
	var w = _make_world(42)
	var state = w.state
	
	# Ensure Hungary has an army
	if not state.armies.has("hungary_horde_1"):
		w.army.create_army("hungary_horde_1", "madari_horde", "uzhorod", "hungary")
	
	# Process campaign
	var report = w.campaign.process_campaign()
	var hungary_events = []
	for event in report.get("events", []):
		if event.get("faction_id", "") == "hungary":
			hungary_events.append(event)
	
	# Verify Hungary is expanding
	assert_true(hungary_events.size() > 0, "Maďari neexpandujú!")
	for event in hungary_events:
		assert_true(event.get("type", "") in ["ai_movement", "ai_siege_start"], "Neočakávaný typ eventu pre Maďarov!")


func test_supply_attrition():
	var w = _make_world(42)
	var state = w.state
	
	# Create an army far from supply
	w.army.create_army("isolated_army", "moravia_levy", "transylvania", "moravia")
	
	# Process campaign
	var report = w.campaign.process_campaign()
	var attrition_events = []
	for event in report.get("events", []):
		if event.get("type", "") == "attrition":
			attrition_events.append(event)
	
	# Verify attrition
	assert_true(attrition_events.size() > 0, "Armáda mimo zásobovania neprešla attríciou!")
	for event in attrition_events:
		assert_eq(event.get("reason", ""), "out_of_supply", "Neočakávaný dôvod attrície!")