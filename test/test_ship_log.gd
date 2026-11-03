extends SceneTree

## Session log: terse entries, ship time, and a LOG command that can be saved later.


func _init() -> void:
	var failed := _run()
	if failed > 0:
		push_error("Ship log tests failed (%d)." % failed)
		quit(1)
	else:
		print("Ship log tests passed.")
		quit(0)


func _run() -> int:
	var failed := 0
	var log_script: Script = load("res://scripts/flight/ship_log.gd")
	var term_script: Script = load("res://scripts/flight/cabin_terminal.gd")
	if log_script == null or term_script == null:
		push_error("ship log scripts missing")
		return 1
	failed += _events(log_script)
	failed += _days_and_save(log_script)
	failed += _command(log_script, term_script)
	return failed


func _events(log_script: Script) -> int:
	var log = log_script.new()
	log.observe(0.2, 0.0, 400.0, 24.0, true, 0.0, false)
	log.observe(0.2, 20.0, 400.0, 24.0, true, 1.0, false)
	log.observe(0.2, 20.0, 40.0, 24.0, false, 0.4, false)
	log.observe(0.2, 20.0, 20.0, 24.0, false, 0.4, true)
	log.note("Cabin lights warm")
	var page: String = log.page()
	if not page.contains("Pilot aboard"):
		push_error("missing aboard entry: %s" % page)
		return 1
	if not page.contains("First burn"):
		push_error("missing burn entry: %s" % page)
		return 1
	if not page.contains("Pilot went to Mina"):
		push_error("missing Mina entry: %s" % page)
		return 1
	if not page.contains("Mina air"):
		push_error("missing atmosphere entry: %s" % page)
		return 1
	if not page.contains("Bay open"):
		push_error("missing bay entry: %s" % page)
		return 1
	if not page.contains("Cabin lights warm"):
		push_error("missing lights entry: %s" % page)
		return 1
	if not page.contains("D0"):
		push_error("entries should carry ship time: %s" % page)
		return 1
	return 0


func _days_and_save(log_script: Script) -> int:
	var log = log_script.new()
	log.observe(log_script.MINA_DAY * 3.0, 0.0, 800.0, 24.0, false, 0.0, false)
	if not log.page().contains("3 Mina days"):
		push_error("three Mina days should be logged, got %s" % log.page())
		return 1
	log.observe(log_script.MINA_DAY, 0.0, 800.0, 24.0, true, 0.0, false)
	if not log.page().contains("Mina day aboard"):
		push_error("a Mina day aboard should be logged, got %s" % log.page())
		return 1
	var saved: Dictionary = log.to_save()
	if int(saved.get("count", 0)) < 2:
		push_error("save payload should keep the entries")
		return 1
	if not saved.has("entries") or not saved.has("elapsed"):
		push_error("save payload should be ready for a future save system")
		return 1
	return 0


func _command(log_script: Script, term_script: Script) -> int:
	var log = log_script.new()
	var lamps_script: Script = load("res://scripts/flight/cabin_lamps.gd")
	var lamps = lamps_script.new()
	log.note("Pilot aboard")
	var help: String = term_script.submit("HELP", lamps, log)
	if not help.contains("LOG"):
		push_error("HELP should list LOG, got %s" % help)
		return 1
	var shown: String = term_script.submit("LOG", lamps, log)
	if not shown.contains("Pilot aboard"):
		push_error("LOG should print the session, got %s" % shown)
		return 1
	if log.blip:
		push_error("reading the log should clear the new-entry blip")
		return 1
	return 0
