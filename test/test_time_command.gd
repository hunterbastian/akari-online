extends SceneTree

## TIME prints the Mina-day ship clock, time flown, and time in space.


func _init() -> void:
	var failed := _run()
	if failed > 0:
		push_error("Time command tests failed (%d)." % failed)
		quit(1)
	else:
		print("Time command tests passed.")
		quit(0)


func _run() -> int:
	var failed := 0
	var log_script: Script = load("res://scripts/flight/ship_log.gd")
	var term_script: Script = load("res://scripts/flight/cabin_terminal.gd")
	var lamps_script: Script = load("res://scripts/flight/cabin_lamps.gd")
	if log_script == null or term_script == null:
		push_error("time command scripts missing")
		return 1
	failed += _clock(log_script)
	failed += _command(log_script, term_script, lamps_script)
	return failed


func _clock(log_script: Script) -> int:
	if absf(float(log_script.MINA_DAY) - 180.0) > 0.01:
		push_error("Mina day should stay 180 real seconds")
		return 1
	var log = log_script.new()
	log.observe(90.0, 12.0, 800.0, 24.0, false, 0.2, false)
	var report: String = log.time_report()
	if not report.contains("SHIP D0 12:"):
		push_error("half a Mina day should read noon, got %s" % report)
		return 1
	if not report.contains("SPACE 00:01:30"):
		push_error("space time should be real session time, got %s" % report)
		return 1
	if not report.contains("FLOWN 00:01:30"):
		push_error("flown time should count while the ship is moving, got %s" % report)
		return 1
	log.observe(180.0, 0.0, 800.0, 24.0, true, 0.0, false)
	var later: String = log.time_report()
	if not later.contains("SHIP D1 12:"):
		push_error("the next half day should roll the Mina day, got %s" % later)
		return 1
	if not later.contains("FLOWN 00:01:30"):
		push_error("sitting still should not add flown time, got %s" % later)
		return 1
	if not later.contains("SPACE 00:04:30"):
		push_error("space time should keep counting, got %s" % later)
		return 1
	return 0


func _command(log_script: Script, term_script: Script, lamps_script: Script) -> int:
	var log = log_script.new()
	var lamps = lamps_script.new()
	log.observe(10.0, 0.0, 800.0, 24.0, true, 0.0, false)
	var help: String = term_script.submit("HELP", lamps, log)
	if not help.contains("TIME"):
		push_error("HELP should list TIME, got %s" % help)
		return 1
	var shown: String = term_script.submit("TIME", lamps, log)
	if not shown.begins_with("SHIP ") or not shown.contains("FLOWN") or not shown.contains("SPACE"):
		push_error("TIME should print the three clocks, got %s" % shown)
		return 1
	if term_script.submit("TIME", lamps) != "TIME?":
		push_error("TIME without a log should say so")
		return 1
	return 0
