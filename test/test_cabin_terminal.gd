extends SceneTree

## LIGHTS command: presets, a half-second blend, and a reply the terminal can print.


func _init() -> void:
	var failed := _run()
	if failed > 0:
		push_error("Cabin terminal tests failed (%d)." % failed)
		quit(1)
	else:
		print("Cabin terminal tests passed.")
		quit(0)


func _run() -> int:
	var failed := 0
	var lamps_script: Script = load("res://scripts/flight/cabin_lamps.gd")
	var term_script: Script = load("res://scripts/flight/cabin_terminal.gd")
	if lamps_script == null or term_script == null:
		push_error("cabin terminal scripts missing")
		return 1
	failed += _help_and_list(term_script, lamps_script)
	failed += _presets_persist(term_script, lamps_script)
	failed += _blend(lamps_script)
	failed += _red_pulses(lamps_script)
	return failed


func _help_and_list(term_script: Script, lamps_script: Script) -> int:
	var lamps = lamps_script.new()
	var help: String = term_script.submit("HELP", lamps)
	if not help.contains("LIGHTS"):
		push_error("HELP should list LIGHTS, got %s" % help)
		return 1
	var listed: String = term_script.submit("LIGHTS", lamps)
	if not listed.contains("WARM") or not listed.contains("COLD") or not listed.contains("RED") or not listed.contains("OFF"):
		push_error("LIGHTS alone should list presets, got %s" % listed)
		return 1
	if lamps.preset != "":
		push_error("listing presets should not change the room")
		return 1
	if term_script.submit("   ", lamps) != "":
		push_error("blank enter should stay quiet")
		return 1
	return 0


func _presets_persist(term_script: Script, lamps_script: Script) -> int:
	var lamps = lamps_script.new()
	var warm: String = term_script.submit("LIGHTS WARM", lamps)
	if warm != "LIGHTS WARM" or lamps.preset != "warm":
		push_error("WARM should confirm and stick, got %s / %s" % [warm, lamps.preset])
		return 1
	var bad: String = term_script.submit("LIGHTS NOPE", lamps)
	if bad != "LIGHTS?" or lamps.preset != "warm":
		push_error("unknown preset should not change the room, got %s" % bad)
		return 1
	var cold: String = term_script.submit("lights cold", lamps)
	if cold != "LIGHTS COLD" or lamps.preset != "cold":
		push_error("choice should persist as the latest preset, got %s" % lamps.preset)
		return 1
	if term_script.submit("SCAN", lamps) != "?":
		push_error("unknown commands should answer ?")
		return 1
	if lamps.preset != "cold":
		push_error("unknown command changed the lights")
		return 1
	return 0


func _blend(lamps_script: Script) -> int:
	var lamps = lamps_script.new()
	lamps.set_preset("off")
	if lamps.gain < 0.9:
		push_error("blend should start from the current room")
		return 1
	_hold(lamps, 0.12)
	if lamps.gain < 0.3 or lamps.gain > 0.85:
		push_error("blend should be partway at 0.12s, got %s" % lamps.gain)
		return 1
	_hold(lamps, 0.5)
	if lamps.gain > 0.08:
		push_error("OFF should be dark after about half a second, got %s" % lamps.gain)
		return 1
	return 0


func _red_pulses(lamps_script: Script) -> int:
	var lamps = lamps_script.new()
	lamps.set_preset("red")
	_hold(lamps, 0.6)
	var low: float = lamps.shown_gain()
	_hold(lamps, 1.0)
	var high: float = lamps.shown_gain()
	if absf(low - high) < 0.08:
		push_error("RED should pulse, got %s then %s" % [low, high])
		return 1
	if lamps.tint.r < lamps.tint.b:
		push_error("RED should stay red while it pulses")
		return 1
	return 0


func _hold(lamps, seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		var step := minf(left, 1.0 / 60.0)
		lamps.advance(step)
		left -= step
