# test/integration/test_campaign_determinism.gd
extends "../test_base.gd"


func test_campaign_determinism():
	var w1 = _make_world(42)
	var w2 = _make_world(42)
	
	# Process campaign twice with same seed
	var c1 = w1.campaign.process_campaign()
	var c2 = w2.campaign.process_campaign()
	
	# Compare events
	assert_eq(c1, c2, "Campaign AI nie je deterministická!")


func test_campaign_different_seeds():
	var w1 = _make_world(42)
	var w2 = _make_world(77)
	
	# Process campaign with different seeds
	var c1 = w1.campaign.process_campaign()
	var c2 = w2.campaign.process_campaign()
	
	# Ensure outputs are different
	assert_true(c1 != c2, "Campaign AI by mala byť rôzna pre rôzne seedy!")