extends Node3D

const _ColorGrade := preload("res://scripts/world/color_grade.gd")

## Sol, one seeded world, the starter ship.

var _shot := false
var _title_card := false
var _shot_time := 0.0
var _shot_saved := false


func _ready() -> void:
	_shot = OS.get_environment("AKARI_SHOT") == "1"
	_title_card = OS.get_environment("AKARI_TITLE") == "1"
	DisplayServer.window_set_title("AKARI ONLINE")
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
	_add_planet_haze(planet)

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
	if _shot and OS.get_environment("AKARI_CLOSEUP") == "1":
		_frame_closeup(ship, camera)

	if not _shot or _title_card:
		_build_hint()


func _process(delta: float) -> void:
	if _title_card and not _shot_saved:
		_shot_time += delta
		if _shot_time >= 0.7:
			_shot_saved = true
			_capture.call_deferred()
		return
	if not _shot or _shot_saved:
		return
	_shot_time += delta
	var still_at := 8.0
	var still_env := OS.get_environment("AKARI_SHOT_AT")
	if not still_env.is_empty():
		still_at = float(still_env)
	if _shot_time < still_at:
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
	var sun_dir := FlightProfile.SUN_OFFSET.normalized()
	var right := sun_dir.cross(Vector3.UP).normalized()
	var up := right.cross(sun_dir).normalized()
	var radius: float = planet.radius
	# Aim 20 degrees below the sun so the disc sits above Mina.
	var look_dir := (sun_dir * cos(deg_to_rad(20.0)) - up * sin(deg_to_rad(20.0)) + right * 0.08).normalized()
	ship.global_position = center - look_dir * radius * 14.2
	ship.look_at(center, Vector3.UP)


func _frame_closeup(ship: Node3D, camera: Camera3D) -> void:
	var forward := -ship.global_basis.z
	var right := ship.global_basis.x
	camera.set_script(null)
	camera.current = true
	camera.fov = 28.0
	camera.global_position = ship.global_position - forward * 11.0 + right * 5.8 + Vector3.UP * 2.6
	camera.look_at(ship.global_position + forward * 0.15, Vector3.UP)


func _build_environment(sky_colors: Dictionary, sun_dir: Vector3) -> void:
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.background_energy_multiplier = 1.0
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.68, 0.82)
	environment.ambient_light_energy = 0.16
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_exposure = 1.02
	environment.tonemap_white = 6.0

	environment.glow_enabled = true
	environment.glow_intensity = 0.8
	environment.glow_strength = 0.72
	environment.glow_bloom = 0.14
	environment.glow_hdr_threshold = 0.85
	environment.glow_hdr_scale = 1.6
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	environment.ssao_enabled = true
	environment.ssao_radius = 1.4
	environment.ssao_intensity = 1.35
	environment.ssao_power = 1.4
	environment.ssao_detail = 0.45
	environment.ssao_horizon = 0.08
	environment.ssao_sharpness = 0.98
	environment.ssao_light_affect = 0.35

	environment.ssr_enabled = true
	environment.ssr_max_steps = 48
	environment.ssr_fade_in = 0.12
	environment.ssr_fade_out = 1.8
	environment.ssr_depth_tolerance = 0.25

	environment.sdfgi_enabled = true
	environment.sdfgi_cascades = 4
	environment.sdfgi_min_cell_size = 0.4
	environment.sdfgi_cascade0_distance = 24.0
	environment.sdfgi_max_distance = 512.0
	environment.sdfgi_y_scale = Environment.SDFGI_Y_SCALE_75_PERCENT
	environment.sdfgi_use_occlusion = true
	environment.sdfgi_bounce_feedback = 0.35
	environment.sdfgi_energy = 0.55
	environment.sdfgi_read_sky_light = true

	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.0
	environment.volumetric_fog_albedo = Color(0.55, 0.7, 0.84)
	environment.volumetric_fog_emission = Color(0.01, 0.02, 0.035)
	environment.volumetric_fog_length = 64.0
	environment.volumetric_fog_detail_spread = 2.0
	environment.volumetric_fog_ambient_inject = 0.35
	environment.volumetric_fog_sky_affect = 0.15

	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.0
	environment.adjustment_contrast = 1.04
	environment.adjustment_saturation = 0.9
	environment.adjustment_color_correction = _ColorGrade.build_lut()

	var sky := Sky.new()
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/shaders/nebula_sky.gdshader")
	material.set_shader_parameter("sun_dir", sun_dir)
	sky.sky_material = material
	environment.sky = sky
	world.environment = environment
	add_child(world)
	_log_features(environment, sky_colors)


func _build_key_light(_sky_colors: Dictionary, sun_dir: Vector3) -> void:
	var key := DirectionalLight3D.new()
	key.name = "SunLight"
	key.light_color = Color(1.0, 0.94, 0.82)
	key.light_energy = 2.6
	key.shadow_enabled = true
	key.shadow_blur = 1.7
	key.light_angular_distance = 0.7
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	key.directional_shadow_blend_splits = true
	key.directional_shadow_max_distance = 900.0
	key.directional_shadow_fade_start = 0.85
	key.look_at_from_position(sun_dir, Vector3.ZERO, Vector3.UP)
	add_child(key)

	var fill := DirectionalLight3D.new()
	fill.name = "SkyFill"
	fill.light_color = Color(0.62, 0.74, 0.9)
	fill.light_energy = 0.2
	fill.shadow_enabled = false
	fill.look_at_from_position(-sun_dir, Vector3.ZERO, Vector3.UP)
	add_child(fill)


func _build_sun(_sky_colors: Dictionary) -> void:
	var sun_dir := FlightProfile.SUN_OFFSET.normalized()
	var distance := 1800.0
	var star := Node3D.new()
	star.name = "Star"
	star.position = sun_dir * distance
	add_child(star)

	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 58.0
	core_mesh.height = 116.0
	core_mesh.radial_segments = 32
	core_mesh.rings = 16
	core.mesh = core_mesh
	var core_mat := StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.albedo_color = Color(8.0, 7.4, 6.2, 1.0)
	core.material_override = core_mat
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	star.add_child(core)

	var glow := MeshInstance3D.new()
	var glow_mesh := SphereMesh.new()
	glow_mesh.radius = 150.0
	glow_mesh.height = 300.0
	glow_mesh.radial_segments = 28
	glow_mesh.rings = 16
	glow.mesh = glow_mesh
	var glow_mat := StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	glow_mat.albedo_color = Color(1.6, 1.75, 2.1, 0.35)
	glow.material_override = glow_mat
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	star.add_child(glow)


func _add_planet_haze(planet: Dictionary) -> void:
	var volume := FogVolume.new()
	volume.name = "PlanetHaze"
	volume.shape = 0
	var radius: float = planet.radius
	volume.size = Vector3.ONE * radius * 3.4
	volume.position = planet.position
	var fog := FogMaterial.new()
	fog.density = 0.008
	fog.albedo = Color(0.45, 0.66, 0.82)
	fog.emission = Color(0.015, 0.03, 0.05)
	volume.material = fog
	add_child(volume)


func _log_features(environment: Environment, _sky_colors: Dictionary) -> void:
	var adapter := ""
	if RenderingServer.has_method("get_video_adapter_name"):
		adapter = str(RenderingServer.get_video_adapter_name())
	print("RENDER adapter=", adapter)
	print(
		"FEATURES agx=%s glow=%s ssao=%s ssr=%s sdfgi=%s volfog=%s lut=%s"
		% [
			environment.tonemap_mode == Environment.TONE_MAPPER_AGX,
			environment.glow_enabled,
			environment.ssao_enabled,
			environment.ssr_enabled,
			environment.sdfgi_enabled,
			environment.volumetric_fog_enabled,
			environment.adjustment_color_correction != null,
		]
	)


func _build_hint() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Title"
	layer.set_script(load("res://scripts/ui/title_card.gd"))
	add_child(layer)
