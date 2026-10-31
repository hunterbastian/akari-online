extends Node3D

const _ColorGrade := preload("res://scripts/world/color_grade.gd")
const _PostProfile := preload("res://scripts/data/post_profile.gd")

## Sol, one seeded world, the starter ship.

var _shot := false
var _title_card := false
var _cabin_view := ""
var _shot_time := 0.0
var _shot_frames := 0
var _shot_saved := false
var _cli_shot := ""
var _cli_at := ""
var _world: SubViewport
var _bounce: DirectionalLight3D
var _ship: Node3D
var _dither_layer: CanvasLayer
var _planet: Dictionary = {}
var _planet_center := Vector3.ZERO
var _planet_radius := 24.0


func _ready() -> void:
	_shot = OS.get_environment("AKARI_SHOT") == "1" or OS.get_environment("AKARI_HERO") == "1"
	_title_card = OS.get_environment("AKARI_TITLE") == "1"
	_cabin_view = OS.get_environment("AKARI_CABIN")
	_read_cli()
	DisplayServer.window_set_title("AKARI ONLINE")
	_mount_world()
	var system := Galaxy.system_by_id(GameState.system_id)
	var chart := Universe.generate_system(system)
	var planet: Dictionary = chart.planets[0]
	_planet = planet
	var sky: Dictionary = chart.sky
	var sun_dir := FlightProfile.SUN_OFFSET.normalized()

	_build_environment(sky, sun_dir)
	_build_sun(sky)
	_build_key_light(sky, sun_dir)

	var body := PlanetBody.new()
	body.name = planet.name
	_world.add_child(body)
	body.setup(planet, sun_dir)
	_planet_center = planet.position
	_planet_radius = float(planet.radius)

	var ship := Node3D.new()
	ship.name = "Ship"
	ship.set_script(load("res://scripts/flight/ship_controller.gd"))
	ship.set_meta("flight_active", _shot or not _cabin_view.is_empty())
	_world.add_child(ship)
	ship.planet_position = planet.position
	ship.planet_radius = planet.radius
	_ship = ship
	if _shot or not _cabin_view.is_empty():
		_place_for_shot(ship, planet)
	else:
		ship.global_position = chart.spawn
		ship.look_at(planet.position, Vector3.UP)

	var camera := Camera3D.new()
	camera.name = "ChaseCamera"
	camera.set_script(load("res://scripts/flight/chase_camera.gd"))
	camera.ship_path = ship.get_path()
	camera.set_meta("title_hold", not _shot)
	camera.set_meta("planet_center", planet.position)
	camera.set_meta("planet_radius", float(planet.radius))
	_world.add_child(camera)
	if _shot and OS.get_environment("AKARI_HERO") == "1":
		_frame_hero(ship, camera)
	elif _shot and OS.get_environment("AKARI_CLOSEUP") == "1":
		_frame_closeup(ship, camera)
	elif _shot and OS.get_environment("AKARI_SIDE") == "1":
		_frame_side(ship, camera)
	elif not _shot and _cabin_view.is_empty():
		var director = load("res://scripts/ui/title_director.gd").new()
		director.name = "TitleDirector"
		add_child(director)
		director.setup(ship, camera, planet.position, float(planet.radius), sun_dir)
	var hud = load("res://scripts/ui/flight_hud.gd").new()
	hud.name = "FlightHud"
	hud.add_to_group("akari_hud")
	add_child(hud)
	hud.setup(ship)
	var cabin_controls = load("res://scripts/ui/cabin_controls.gd").new()
	cabin_controls.name = "CabinControls"
	cabin_controls.add_to_group("akari_hud")
	add_child(cabin_controls)
	cabin_controls.setup(ship)
	ship.set_chase_camera(camera)
	ship.set_cabin_controls(cabin_controls)
	if not _cabin_view.is_empty():
		ship.start_cabin_view(_cabin_view)
	if not _cli_at.is_empty():
		dev_teleport(_cli_at)
	_add_sun_glare(camera, sun_dir)
	_add_dither()
	_update_bounce()
	if OS.get_environment("AKARI_CONSOLE") == "1":
		DevConsole.present()


func _mount_world() -> void:
	var layer := CanvasLayer.new()
	layer.name = "View"
	layer.layer = 0
	var frame := TextureRect.new()
	frame.name = "Frame"
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var view := SubViewport.new()
	view.name = "World"
	view.own_world_3d = true
	view.handle_input_locally = false
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	frame.add_child(view)
	frame.texture = view.get_texture()
	layer.add_child(frame)
	add_child(layer)
	_world = view
	get_viewport().size_changed.connect(_apply_render_scale)
	_apply_render_scale()


func apply_render_scale() -> void:
	_apply_render_scale()


func _apply_render_scale() -> void:
	var full := get_viewport().get_visible_rect().size
	var scale := _PostProfile.render_scale()
	_world.size = Vector2i(
		maxi(1, int(round(full.x * scale))),
		maxi(1, int(round(full.y * scale)))
	)


func set_dither_enabled(on: bool) -> void:
	if on:
		_add_dither()
		return
	if is_instance_valid(_dither_layer):
		_dither_layer.visible = false


func _add_dither() -> void:
	if not _PostProfile.dither_enabled():
		return
	if is_instance_valid(_dither_layer):
		_dither_layer.visible = true
		return
	var layer := CanvasLayer.new()
	layer.name = "Dither"
	layer.layer = 1
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/shaders/film_dither.gdshader")
	rect.material = material
	layer.add_child(rect)
	# Inside the low-res view, so the Bayer grid is one step per rendered pixel.
	_world.add_child(layer)
	_dither_layer = layer


func _add_sun_glare(chase: Camera3D, sun_dir: Vector3) -> void:
	var glare = load("res://scripts/world/sun_glare.gd").new()
	glare.name = "SunGlare"
	# Inside the low-res view, under the dither layer, so the flare is dithered like the world.
	_world.add_child(glare)
	glare.setup(_world, sun_dir * 1800.0, _planet_center, _planet_radius)


func _update_bounce() -> void:
	if _bounce == null or _ship == null:
		return
	# Light travels from Mina to the ship. Stronger close in, gone far out.
	var offset := _ship.global_position - _planet_center
	var distance := maxf(offset.length(), 0.001)
	_bounce.look_at_from_position(Vector3.ZERO, offset / distance, Vector3.UP if absf(offset.normalized().y) < 0.98 else Vector3.RIGHT)
	var near := clampf(1.0 - (distance - _planet_radius) / (_planet_radius * 8.0), 0.0, 1.0)
	_bounce.light_energy = 0.08 + 0.32 * near * near


func _process(delta: float) -> void:
	_update_bounce()
	if not _cli_shot.is_empty():
		if _shot_saved:
			return
		_shot_time += delta
		_shot_frames += 1
		# Nested CRT viewports need a few real frames before the shot is honest.
		if _shot_time < 0.6 or _shot_frames < 8:
			return
		_shot_saved = true
		_run_cli_shot()
		return
	if _title_card and not _shot and not _shot_saved:
		_shot_time += delta
		if _shot_time >= 2.4:
			_shot_saved = true
			_capture.call_deferred()
		return
	if (not _shot and _cabin_view.is_empty()) or _shot_saved:
		return
	_shot_time += delta
	_shot_frames += 1
	var still_at := 8.0 if _cabin_view.is_empty() else 1.2
	var still_env := OS.get_environment("AKARI_SHOT_AT")
	if not still_env.is_empty():
		still_at = float(still_env)
	# Nested CRT viewports need a few real frames; a long first frame must not skip them.
	if _shot_time < still_at or _shot_frames < 4:
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


func _frame_portrait(ship: Node3D, camera: Camera3D, offset: Vector3, aim: Vector3, fov: float) -> void:
	camera.set_script(null)
	camera.current = true
	camera.fov = fov
	camera.global_position = ship.global_position + offset
	camera.look_at(ship.global_position + aim, Vector3.UP)


func _frame_closeup(ship: Node3D, camera: Camera3D) -> void:
	var forward := -ship.global_basis.z
	var right := ship.global_basis.x
	_frame_portrait(
		ship,
		camera,
		-forward * 8.2 + right * 7.4 + Vector3.UP * 2.5,
		Vector3.ZERO,
		30.0,
	)


func _frame_hero(ship: Node3D, camera: Camera3D) -> void:
	var forward := -ship.global_basis.z
	var right := ship.global_basis.x
	# Low front three-quarter, so the white nose and canopy take the sun.
	_frame_portrait(ship, camera, forward * 7.4 + right * 5.6 + Vector3.UP * 1.7, forward * 0.8, 26.0)


func _frame_side(ship: Node3D, camera: Camera3D) -> void:
	var right := ship.global_basis.x
	_frame_portrait(ship, camera, right * 11.5 + Vector3.UP * 1.35, Vector3.ZERO, 28.0)


func dev_teleport(spec: String) -> String:
	if _ship == null:
		return "no ship"
	var parts: PackedStringArray = spec.split(" ", false)
	if parts.is_empty():
		return "tp needs a target"
	if parts.size() >= 3 and parts[0].is_valid_float() and parts[1].is_valid_float() and parts[2].is_valid_float():
		var at := Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
		_ship.dev_leave_cabin()
		_ship.velocity = Vector3.ZERO
		_ship.global_position = at
		return "tp %s" % str(at)
	var key := parts[0].to_lower()
	if key == "planet":
		_ship.dev_leave_cabin()
		_ship.velocity = Vector3.ZERO
		_place_for_shot(_ship, _planet)
		return "tp planet"
	if key == "moon":
		return _tp_moon()
	if key == "ship":
		_ship.dev_leave_cabin()
		_ship.velocity = Vector3.ZERO
		return "tp ship %s" % str(_ship.global_position)
	if key == "cabin" or key == "seat":
		_place_for_shot(_ship, _planet)
		_ship.velocity = Vector3.ZERO
		_ship.start_cabin_view("seat")
		return "tp cabin"
	if key == "aisle":
		_place_for_shot(_ship, _planet)
		_ship.velocity = Vector3.ZERO
		_ship.start_cabin_view("aisle")
		return "tp aisle"
	if key == "rear" or key == "back":
		_place_for_shot(_ship, _planet)
		_ship.velocity = Vector3.ZERO
		_ship.start_cabin_view("rear")
		return "tp rear"
	if key == "dash":
		_place_for_shot(_ship, _planet)
		_ship.velocity = Vector3.ZERO
		_ship.start_cabin_view("dash")
		return "tp dash"
	if key == "storage":
		_place_for_shot(_ship, _planet)
		_ship.velocity = Vector3.ZERO
		_ship.start_cabin_view("storage")
		return "tp storage"
	return "unknown tp target '%s'" % key


func _tp_moon() -> String:
	var body := _world.get_node_or_null(str(_planet.get("name", "")))
	if body == null:
		return "no planet"
	var moon := body.get_node_or_null("Moon") as Node3D
	if moon == null:
		return "no moon"
	_ship.dev_leave_cabin()
	_ship.velocity = Vector3.ZERO
	var pos := moon.global_position
	var away := pos - _planet_center
	if away.length_squared() < 0.01:
		away = Vector3.UP
	_ship.global_position = pos + away.normalized() * 6.0
	_ship.look_at(pos, Vector3.UP)
	return "tp moon"


func _read_cli() -> void:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		var arg := str(args[i])
		if arg == "--shot" and i + 1 < args.size():
			_cli_shot = str(args[i + 1])
			_shot = true
			i += 2
		elif arg == "--at" and i + 1 < args.size():
			_cli_at = str(args[i + 1])
			i += 2
		else:
			i += 1
	if _cli_at.is_empty():
		return
	var at := _cli_at.to_lower()
	if at == "cabin" or at == "seat":
		_cabin_view = "seat"
	elif at == "aisle":
		_cabin_view = "aisle"
	elif at == "rear" or at == "back":
		_cabin_view = "rear"
	elif at == "dash":
		_cabin_view = "dash"
	elif at == "storage":
		_cabin_view = "storage"
	else:
		_cabin_view = ""


func _run_cli_shot() -> void:
	await DevConsole.capture_screenshot(1.0, false, _cli_shot)
	get_tree().quit()


func _build_environment(sky_colors: Dictionary, sun_dir: Vector3) -> void:
	var high := _PostProfile.high_quality()
	var med := _PostProfile.detailed()
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.background_energy_multiplier = 1.0
	# Cold, low ambient: shadow sides fall to near black instead of grey.
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.36, 0.5, 0.72)
	environment.ambient_light_energy = 0.045
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_exposure = 1.0
	environment.tonemap_white = 6.0

	# Bloom only well above white: the sun, its glare and the engines. The frame itself stays crisp.
	environment.glow_enabled = true
	environment.glow_normalized = false
	environment.glow_intensity = 0.65
	environment.glow_strength = 0.9
	environment.glow_bloom = 0.0
	environment.glow_hdr_threshold = 2.4
	environment.glow_hdr_scale = 2.2
	environment.glow_hdr_luminance_cap = 24.0
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	environment.set_glow_level(0, 0.0)
	environment.set_glow_level(1, 0.6)
	environment.set_glow_level(2, 0.8)
	environment.set_glow_level(3, 0.35)
	environment.set_glow_level(4, 0.12)

	environment.ssao_enabled = med
	environment.ssao_radius = 1.1
	environment.ssao_intensity = 1.6
	environment.ssao_power = 1.5
	environment.ssao_detail = 0.5
	environment.ssao_horizon = 0.06
	environment.ssao_sharpness = 0.98
	environment.ssao_light_affect = 0.2

	# Sharp canopy and panel reflections of Mina and the engines.
	environment.ssr_enabled = high
	environment.ssr_max_steps = 56
	environment.ssr_fade_in = 0.08
	environment.ssr_fade_out = 2.0
	environment.ssr_depth_tolerance = 0.2

	# GI does little in open space and costs a lot; the ship bounce is a dedicated light instead.
	environment.sdfgi_enabled = false
	# Volumetric fog washed the close ring pass into flat grey sheets. Limb haze lives in the
	# atmosphere shells now, which stay crisp at any distance.
	environment.volumetric_fog_enabled = false

	environment.adjustment_enabled = true
	environment.adjustment_brightness = 0.98
	environment.adjustment_contrast = 1.08
	environment.adjustment_saturation = 1.0
	environment.adjustment_color_correction = _ColorGrade.build_lut()

	var sky := Sky.new()
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/shaders/nebula_sky.gdshader")
	material.set_shader_parameter("sun_dir", sun_dir)
	sky.sky_material = material
	var radiance := Sky.RADIANCE_SIZE_64
	if high:
		radiance = Sky.RADIANCE_SIZE_256
	elif med:
		radiance = Sky.RADIANCE_SIZE_128
	sky.radiance_size = radiance
	environment.sky = sky
	world.environment = environment
	_world.add_child(world)
	_log_features(environment, sky_colors)


func _build_key_light(_sky_colors: Dictionary, sun_dir: Vector3) -> void:
	var high := _PostProfile.high_quality()
	# One hard sun: small angular size and little blur, so terminators and hull shadows are crisp.
	var key := DirectionalLight3D.new()
	key.name = "SunLight"
	key.light_color = Color(1.0, 0.95, 0.86)
	key.light_energy = 2.4
	key.light_specular = 1.0
	key.shadow_enabled = true
	key.shadow_blur = 0.6
	key.light_angular_distance = 0.25
	key.shadow_normal_bias = 1.2
	if high:
		key.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	else:
		key.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	key.directional_shadow_blend_splits = high
	key.directional_shadow_max_distance = 600.0
	key.directional_shadow_fade_start = 0.85
	key.look_at_from_position(sun_dir, Vector3.ZERO, Vector3.UP)
	_world.add_child(key)

	# Thin cool rim on the shadow side: almost no diffuse, mostly a specular edge.
	var rim := DirectionalLight3D.new()
	rim.name = "CoolRim"
	rim.light_color = Color(0.5, 0.68, 1.0)
	rim.light_energy = 0.12
	rim.light_specular = 1.6
	rim.shadow_enabled = false
	rim.look_at_from_position(-sun_dir + Vector3(0.0, -0.25, 0.0), Vector3.ZERO, Vector3.UP)
	_world.add_child(rim)

	# Mina-blue bounce: a weak fill aimed from the planet at the ship, updated each frame.
	_bounce = DirectionalLight3D.new()
	_bounce.name = "PlanetBounce"
	_bounce.light_color = Color(0.42, 0.64, 0.95)
	_bounce.light_energy = 0.0
	_bounce.light_specular = 0.6
	_bounce.shadow_enabled = false
	_world.add_child(_bounce)


func _build_sun(_sky_colors: Dictionary) -> void:
	var sun_dir := FlightProfile.SUN_OFFSET.normalized()
	var distance := 1800.0
	var star := Node3D.new()
	star.name = "Star"
	star.position = sun_dir * distance
	_world.add_child(star)

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
	glow_mesh.radius = 96.0
	glow_mesh.height = 192.0
	glow_mesh.radial_segments = 28
	glow_mesh.rings = 16
	glow.mesh = glow_mesh
	var glow_mat := StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	glow_mat.albedo_color = Color(0.85, 0.95, 1.15, 0.14)
	glow.material_override = glow_mat
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	star.add_child(glow)


func _log_features(environment: Environment, _sky_colors: Dictionary) -> void:
	var adapter := ""
	if RenderingServer.has_method("get_video_adapter_name"):
		adapter = str(RenderingServer.get_video_adapter_name())
	print("RENDER adapter=", adapter)
	print(
		"FEATURES quality=%s agx=%s glow=%s ssao=%s ssr=%s sdfgi=%s volfog=%s lut=%s"
		% [
			_PostProfile.quality(),
			environment.tonemap_mode == Environment.TONE_MAPPER_AGX,
			environment.glow_enabled,
			environment.ssao_enabled,
			environment.ssr_enabled,
			environment.sdfgi_enabled,
			environment.volumetric_fog_enabled,
			environment.adjustment_color_correction != null,
		]
	)


