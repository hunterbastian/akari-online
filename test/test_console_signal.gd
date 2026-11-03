extends SceneTree

## The console signal after the film pass: deflicker and composite amounts, and the shader they drive.


func _init() -> void:
	var failed := _run()
	if failed > 0:
		push_error("Console signal tests failed (%d)." % failed)
		quit(1)
	else:
		print("Console signal tests passed.")
		quit(0)


func _run() -> int:
	var failed := 0
	var post: Script = load("res://scripts/data/post_profile.gd")
	var shader: Shader = load("res://assets/shaders/console_signal.gdshader")
	if post == null or shader == null:
		push_error("console signal script or shader missing")
		return 1
	failed += _amounts(post)
	failed += _uniforms(shader)
	return failed


func _amounts(post: Script) -> int:
	var failed := 0
	if absf(post.deflicker() - post.DEFLICKER) > 0.001 or absf(post.composite() - post.COMPOSITE) > 0.001:
		push_error("with no override the amounts should be the defaults")
		failed += 1
	if post.DEFLICKER <= 0.0 or post.COMPOSITE <= 0.0:
		push_error("both passes should be on by default")
		failed += 1
	post.runtime_deflicker = 0.0
	post.runtime_composite = 3.0
	if post.deflicker() != 0.0:
		push_error("deflicker off should read 0, got %s" % str(post.deflicker()))
		failed += 1
	if post.composite() != 1.0:
		push_error("composite should clamp to 1, got %s" % str(post.composite()))
		failed += 1
	post.runtime_deflicker = -1.0
	post.runtime_composite = -1.0
	return failed


func _uniforms(shader: Shader) -> int:
	var names: Array[String] = []
	for uniform in shader.get_shader_uniform_list():
		names.append(str(uniform["name"]))
	for want in ["deflicker", "composite"]:
		if not names.has(want):
			push_error("console_signal.gdshader should have a %s uniform, has %s" % [want, str(names)])
			return 1
	return 0
