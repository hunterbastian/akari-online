extends Node3D

## Sol, one seeded world, the starter ship.

var _shot := false
var _shot_time := 0.0
var _shot_saved := false


func _ready() -> void:
	_shot = OS.get_environment("AKARI_SHOT") == "1"
	var system := Galaxy.system_by_id(GameState.system_id)
	var chart := Universe.generate_system(system)
	var planet: Dictionary = chart.planets[0]
	var sky: Dictionary = chart.sky
	var sun_dir := FlightProfile.SUN_OFFSET.normalized()

	_build_environment(sky, sun_dir)
	_build_sun(sky)
	_build_key_light(sky, sun_dir)

	var body := PlanetBody.new()
	body.name = planet.name
	add_child(body)
	body.setup(planet, sun_dir)

	var ship := Node3D.new()
	ship.name = "Ship"
	ship.set_script(load("res://scripts/flight/ship_controller.gd"))
	add_child(ship)
	ship.planet_position = planet.position
	ship.planet_radius = planet.radius
	if _shot:
		_place_for_shot(ship, planet)
	else:
		ship.global_position = chart.spawn
		ship.look_at(planet.position, Vector3.UP)

	var camera := Camera3D.new()
	camera.name = "ChaseCamera"
	camera.set_script(load("res://scripts/flight/chase_camera.gd"))
	camera.ship_path = ship.get_path()
	add_child(camera)

	if not _shot:
		_build_hint()


func _process(delta: float) -> void:
	if not _shot or _shot_saved:
		return
	_shot_time += delta
	if _shot_time < 0.85:
		return
	_shot_saved = true
	_capture.call_deferred()


func _capture() -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := OS.get_environment("AKARI_SHOT_PATH")
	if path.is_empty():
		path = "/tmp/akari_sol_flight.png"
	image.save_png(path)
	print("Wrote ", path)
	if OS.get_environment("AKARI_SHOT_HOLD") != "1":
		get_tree().quit()


func _place_for_shot(ship: Node3D, planet: Dictionary) -> void:
	var center: Vector3 = planet.position
	var from_star := center.normalized()
	var side := from_star.cross(Vector3.UP).normalized()
	var radius: float = planet.radius
	var offset := (side * 0.95 + from_star * 0.55 + Vector3.UP * 0.22).normalized()
	ship.global_position = center + offset * radius * 5.1
	var look := center + side * radius * 0.35
	ship.look_at(look, Vector3.UP)


func _build_environment(sky_colors: Dictionary, sun_dir: Vector3) -> void:
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.html(sky_colors.mid)
	environment.ambient_light_energy = 0.22
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_exposure = 1.06
	environment.tonemap_white = 6.0
	var sky := Sky.new()
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/shaders/nebula_sky.gdshader")
	material.set_shader_parameter("top_color", Color.html(sky_colors.top))
	material.set_shader_parameter("mid_color", Color.html(sky_colors.mid))
	material.set_shader_parameter("bottom_color", Color.html(sky_colors.bottom))
	material.set_shader_parameter("star_color", Color.html(sky_colors.star))
	material.set_shader_parameter("sun_dir", sun_dir)
	material.set_shader_parameter("yaw", 0.6)
	sky.sky_material = material
	environment.sky = sky
	world.environment = environment
	add_child(world)


func _build_key_light(sky_colors: Dictionary, sun_dir: Vector3) -> void:
	var key := DirectionalLight3D.new()
	key.name = "SunLight"
	key.light_color = Color.html(sky_colors.star)
	key.light_energy = 1.35
	key.shadow_enabled = true
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	key.directional_shadow_max_distance = 420.0
	key.look_at_from_position(sun_dir, Vector3.ZERO, Vector3.UP)
	add_child(key)

	var fill := DirectionalLight3D.new()
	fill.name = "SkyFill"
	fill.light_color = Color.html(sky_colors.bottom)
	fill.light_energy = 0.18
	fill.shadow_enabled = false
	fill.look_at_from_position(-sun_dir + Vector3.UP * 0.35, Vector3.ZERO, Vector3.UP)
	add_child(fill)


func _build_sun(sky_colors: Dictionary) -> void:
	var star := Node3D.new()
	star.name = "Star"
	add_child(star)

	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 4.6
	core_mesh.height = 9.2
	core_mesh.radial_segments = 32
	core_mesh.rings = 16
	core.mesh = core_mesh
	var core_mat := StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.albedo_color = Color.html("#fff8f0")
	core.material_override = core_mat
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	star.add_child(core)

	var glow := MeshInstance3D.new()
	var glow_mesh := SphereMesh.new()
	glow_mesh.radius = 8.4
	glow_mesh.height = 16.8
	glow_mesh.radial_segments = 28
	glow_mesh.rings = 16
	glow.mesh = glow_mesh
	var glow_mat := StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	glow_mat.albedo_color = Color.html(sky_colors.star)
	glow_mat.albedo_color.a = 0.28
	glow.material_override = glow_mat
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	star.add_child(glow)


func _build_hint() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Hint"
	var label := Label.new()
	label.name = "HintLabel"
	label.text = "Click to fly"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_bottom = -28
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color.html("#f6ead4"))
	label.add_theme_color_override("font_shadow_color", Color(0.05, 0.03, 0.08, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 1)
	layer.add_child(label)
	add_child(layer)
	label.set_process(true)
	label.set_script(load("res://scripts/ui/capture_hint.gd"))
