extends SceneTree

## History, tab completion, and a suggested command for a typo.


func _init() -> void:
	var failed := _run()
	if failed > 0:
		push_error("Terminal polish tests failed (%d)." % failed)
		quit(1)
	else:
		print("Terminal polish tests passed.")
		quit(0)


func _run() -> int:
	var failed := 0
	var script: Script = load("res://scripts/flight/terminal_edit.gd")
	var term: Script = load("res://scripts/flight/cabin_terminal.gd")
	if script == null or term == null:
		push_error("terminal edit script missing")
		return 1
	failed += _history(script)
	failed += _complete(script)
	failed += _suggest(script, term)
	return failed


func _history(script: Script) -> int:
	var edit = script.new()
	edit.line = "HELP"
	edit.remember("HELP")
	edit.line = "LOG"
	edit.remember("LOG")
	edit.line = "TI"
	edit.up()
	if edit.line != "LOG":
		push_error("up should recall the last command, got %s" % edit.line)
		return 1
	edit.up()
	if edit.line != "HELP":
		push_error("up again should recall the older command, got %s" % edit.line)
		return 1
	edit.down()
	if edit.line != "LOG":
		push_error("down should walk forward, got %s" % edit.line)
		return 1
	edit.down()
	if edit.line != "TI":
		push_error("down past the end should restore the draft, got %s" % edit.line)
		return 1
	return 0


func _complete(script: Script) -> int:
	if script.complete_text("LI") != "LIGHTS":
		push_error("LI should complete to LIGHTS")
		return 1
	if script.complete_text("LIGHTS W") != "LIGHTS WARM":
		push_error("LIGHTS W should complete to WARM")
		return 1
	if script.complete_text("LIGHTS C") != "LIGHTS COLD":
		push_error("LIGHTS C should complete to COLD")
		return 1
	if script.complete_text("AU") != "AUTOPILOT":
		push_error("AU should complete to AUTOPILOT")
		return 1
	if script.complete_text("AUTOPILOT OR") != "AUTOPILOT ORBIT":
		push_error("AUTOPILOT OR should complete to ORBIT, got %s" % script.complete_text("AUTOPILOT OR"))
		return 1
	if script.complete_text("AUTOPILOT OF") != "AUTOPILOT OFF":
		push_error("AUTOPILOT OF should complete to OFF")
		return 1
	if script.complete_text("") != "HELP":
		push_error("an empty line should complete to HELP")
		return 1
	return 0


func _suggest(script: Script, term: Script) -> int:
	if script.suggest("LIGHS") != "?  TRY LIGHTS":
		push_error("LIGHS should suggest LIGHTS, got %s" % script.suggest("LIGHS"))
		return 1
	if script.suggest("ZZZZ") != "?":
		push_error("a far typo should stay a plain question mark")
		return 1
	var lamps_script: Script = load("res://scripts/flight/cabin_lamps.gd")
	var lamps = lamps_script.new()
	var shown: String = term.submit("LIGHS", lamps)
	if shown != "?  TRY LIGHTS":
		push_error("the terminal should print the suggestion, got %s" % shown)
		return 1
	return 0
