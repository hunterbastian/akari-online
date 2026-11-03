extends SceneTree

## The cockpit is one beige terminal. The side and bay CRTs are gone.


func _init() -> void:
	var failed := _run()
	if failed > 0:
		push_error("Beige terminal tests failed (%d)." % failed)
		quit(1)
	else:
		print("Beige terminal tests passed.")
		quit(0)


func _run() -> int:
	var cabin := FileAccess.get_file_as_string("res://scripts/flight/cabin_interior.gd")
	var shader := FileAccess.get_file_as_string("res://assets/shaders/crt_green.gdshader")
	if cabin.is_empty() or shader.is_empty():
		push_error("terminal sources missing")
		return 1
	if not cabin.contains("BeigeTerminal"):
		push_error("the dash should build one beige terminal")
		return 1
	if cabin.contains("_screen("):
		push_error("side CRT screens should be gone")
		return 1
	if cabin.contains("_set_line(\"nav\"") or cabin.contains("_set_line(\"drive\"") or cabin.contains("_set_line(\"bay\""):
		push_error("readouts should not target the old screens")
		return 1
	if not cabin.contains("NEW LOG"):
		push_error("the log flash should stay on the terminal")
		return 1
	if not shader.contains("filter_linear"):
		push_error("the phosphor should sample linear so angled text stays readable")
		return 1
	return 0
