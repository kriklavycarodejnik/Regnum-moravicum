# test/integration/test_performance.gd
extends "../test_base.gd"


func test_performance_100_armies():
	var w = _make_world(42)
	var state = w.state
	
	# Create 100 armies
	for i in range(100):
		w.army.create_army("army_%d" % i, "moravia_levy", "nitra", "moravia")
	
	# Measure time
	var start_time = Time.get_ticks_usec()
	var report = w.campaign.process_campaign()
	var end_time = Time.get_ticks_usec()
	var duration_ms = (end_time - start_time) / 1000.0
	
	# Verify performance (max 500ms)
	assert_true(duration_ms < 500.0, "Campaign AI je príliš pomalá pre 100 armád! (%.1f ms)" % duration_ms)
	assert_true(report.get("events", []).size() > 0, "Žiadne eventy pre 100 armád!")