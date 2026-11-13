extends SceneTree

## The screensaver waits half a minute of flight, and PHOTO is a real command.


func _init() -> void:
	var failed := _run()
	if failed > 0:
		push_error("Idle drift tests failed (%d)." % failed)
		quit(1)
	else:
		print("Idle drift tests passed.")
		quit(0)


func _run() -> int:
	var drift: Script = load("res://scripts/flight/idle_drift.gd")
	var term: Script = load("res://scripts/flight/cabin_terminal.gd")
	var lamps_script: Script = load("res://scripts/flight/cabin_lamps.gd")
	if drift == null or term == null or lamps_script == null:
		push_error("drift scripts missing")
		return 1
	var failed := 0
	if drift.should_start(29.9, true):
		push_error("29.9s of quiet flight should keep the chase camera")
		failed += 1
	if not drift.should_start(30.0, true):
		push_error("30s of quiet flight should start the orbit")
		failed += 1
	if drift.should_start(40.0, false):
		push_error("the orbit stays off while walking or docked")
		failed += 1
	if absf(drift.blend(0.0)) > 0.001 or absf(drift.blend(1.0) - 1.0) > 0.001:
		push_error("the dolly ease should sit on 0 and 1")
		failed += 1
	if absf(drift.blend(0.5) - 0.5) > 0.001:
		push_error("the dolly ease should pass through the middle")
		failed += 1
	var lamps = lamps_script.new()
	var help: String = term.submit("HELP", lamps)
	if not help.contains("PHOTO"):
		push_error("HELP should list PHOTO, got %s" % help)
		failed += 1
	if term.submit("PHOTO", lamps) != "PHOTO":
		push_error("PHOTO should reply PHOTO")
		failed += 1
	if term.submit("SCAN", lamps) != "?":
		push_error("unknown commands stay unknown")
		failed += 1
	return failed
