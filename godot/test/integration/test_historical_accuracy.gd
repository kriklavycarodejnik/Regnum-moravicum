# test/integration/test_historical_accuracy.gd
extends "../test_base.gd"


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


func test_devine_battle_outcome():
	var w = _make_world(42)
	var state = w.state
	
	# Set up Devín 907 scenario
	state.year = 907
	state.month = 7
	w.army.create_army("moravia_levy_1", "moravia_levy", "bratislava", "moravia")
	w.army.create_army("hungary_horde_1", "madari_horde", "uzhorod", "hungary")
	
	# Process campaign
	var report = w.campaign.process_campaign()
	var devin_events = []
	for event in report.get("events", []):
		if event.get("province_id", "") == "devin":
			devin_events.append(event)
	
	# Verify Devín 907 outcome (should favor defender)
	assert_true(devin_events.size() > 0, "Bitka pri Devíne sa neodohrala!")
	for event in devin_events:
		if event.get("type", "") == "battle":
			assert_eq(event.get("winner", ""), "defender", "Bitka pri Devíne by mala vyhrať Morava!")