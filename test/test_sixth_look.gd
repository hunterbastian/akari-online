extends SceneTree

## Sixth-gen look: presets, the phone drop, and the LOOK terminal command.


func _init() -> void:
	var failed := _run()
	if failed > 0:
		push_error("Sixth look tests failed (%d)." % failed)
		quit(1)
	else:
		print("Sixth look tests passed.")
		quit(0)


func _run() -> int:
	var failed := 0
	failed += _presets()
	failed += _terminal()
	failed += _shader_has_passes()
	return failed


func _presets() -> int:
	var look = load("res://scripts/data/sixth_look.gd")
	var post = load("res://scripts/data/post_profile.gd")
	look.boot()
	if look.preset != "modern" or look.active:
		push_error("default look should be modern")
		return 1
	if look.bits != 36.0 or look.dither_extra != 0.01 or look.bloom != 0.0 or look.dof != 0.0:
		push_error("modern should keep the existing film grade")
		return 1
	if look.scale_for(720.0) > 0.0:
		push_error("modern should leave the render scale alone")
		return 1
	if not look.set_preset("sixth"):
		push_error("sixth should be a preset")
		return 1
	if look.dof <= 0.0 or look.shafts <= 0.0 or look.bloom <= 0.0 or look.deflicker <= 0.0:
		push_error("sixth should turn the stack on, got dof %s shafts %s" % [look.dof, look.shafts])
		return 1
	if look.bits != 32.0 or look.dither_extra != 0.0:
		push_error("the bit crush should reuse one Bayer, got steps %s extra %s" % [look.bits, look.dither_extra])
		return 1
	if look.engine_glow != 0.0:
		push_error("Kawase should replace the engine glow")
		return 1
	var scale: float = look.scale_for(720.0)
	if absf(scale - (480.0 / 720.0)) > 0.002:
		push_error("sixth should aim the view at 480 lines, got %s" % scale)
		return 1
	post.runtime_quality = "low"
	look.set_preset("sixth")
	if look.dof != 0.0 or look.shafts != 0.0 or look.bloom <= 0.0:
		push_error("low quality sixth should drop DoF and god rays")
		return 1
	post.runtime_quality = ""
	look.set_preset("phone")
	if look.dof != 0.0 or look.shafts != 0.0 or look.chroma <= 0.0 or look.bits != 32.0:
		push_error("phone preset should keep the cheap passes only")
		return 1
	if look.set_preset("nope"):
		push_error("unknown preset should be refused")
		return 1
	if look.preset != "phone":
		push_error("a refused preset should leave the current one")
		return 1
	look.set_preset("modern")
	return 0


func _terminal() -> int:
	var term = load("res://scripts/flight/cabin_terminal.gd")
	var lamps = load("res://scripts/flight/cabin_lamps.gd").new()
	var help: String = term.submit("HELP", lamps)
	if not help.contains("LOOK"):
		push_error("HELP should list LOOK, got %s" % help)
		return 1
	if term.submit("LOOK", lamps) != "SIXTH  MODERN  PHONE":
		push_error("LOOK alone should list the presets")
		return 1
	if term.submit("look sixth", lamps) != "LOOK SIXTH":
		push_error("LOOK SIXTH should confirm")
		return 1
	if term.submit("LOOK MODERN", lamps) != "LOOK MODERN":
		push_error("LOOK MODERN should confirm")
		return 1
	if term.submit("LOOK PHONE", lamps) != "LOOK PHONE":
		push_error("LOOK PHONE should confirm")
		return 1
	if term.submit("LOOK NOPE", lamps) != "LOOK?":
		push_error("unknown look should answer LOOK?")
		return 1
	return 0


func _shader_has_passes() -> int:
	var shader := FileAccess.get_file_as_string("res://assets/shaders/film_dither.gdshader")
	var data := FileAccess.get_file_as_string("res://scripts/data/sixth_look.gd")
	for key in ["bloom_strength", "dof_strength", "shaft_strength", "deflicker", "chroma", "crt", "quantize_steps"]:
		if not shader.contains(key):
			push_error("film shader missing %s" % key)
			return 1
	if not data.contains("PASS_DOF") or not data.contains("PASS_SHAFTS") or not data.contains("INTERNAL_LINES"):
		push_error("look data should keep the per-pass switches")
		return 1
	return 0
