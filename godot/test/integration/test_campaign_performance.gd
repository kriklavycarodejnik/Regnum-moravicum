# test/integration/test_campaign_performance.gd
extends "res://test/test_base.gd"


func test_campaign_performance_100_armies():
    # Add 100 armies to the game state
    for i in range(100):
        var army_id = "army_%d" % i
        game_state.armies[army_id] = {
            "faction": "moravia" if i % 2 == 0 else "hungary",
            "location": "devin" if i % 2 == 0 else "pannonia",
            "units": {"infantry": 100, "cavalry": 20},
            "besieging": false,
            "in_battle": false
        }
    
    # Measure execution time (gdUnit4 has no built-in timer, so we use OS.time)
    var start_time = OS.get_unix_time()
    var report = campaign_manager.process_campaign()
    var end_time = OS.get_unix_time()
    
    # Verify execution time is under 1 second (adjust threshold as needed)
    var execution_time = end_time - start_time
    assert_that(execution_time).is_less_equal(1.0), \
        "Campaign processing for 100 armies should take <= 1 second (took %f)" % execution_time
    
    # Verify all armies were processed (no crashes)
    assert_that(report.events.size() + report.sieges.size() + report.expansions.size()).is_greater(0), \
        "Campaign report should contain events for 100 armies"


func test_campaign_memory_usage():
    # Run multiple campaigns and monitor memory (simplified check)
    var initial_memory = OS.get_static_memory_usage()
    
    for i in range(5):
        campaign_manager.process_campaign()
    
    var final_memory = OS.get_static_memory_usage()
    var memory_increase = final_memory - initial_memory
    
    # Allow 10MB increase for 5 campaigns (adjust threshold as needed)
    assert_that(memory_increase).is_less_equal(10 * 1024 * 1024), \
        "Memory usage should not increase excessively after 5 campaigns (increase: %d bytes)" % memory_increase