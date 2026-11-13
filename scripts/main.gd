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
var _cli_hold := ""
var _cli_floor := ""
var _cli_door := ""
var _tour := false
var _world: SubViewport
var _bounce: DirectionalLight3D
var _low_sun := false
var _ship: Node3D
var _dither_layer: CanvasLayer
var _planet: Dictionary = {}
var _planet_center := Vector3.ZERO
var _planet_radius := 24.0
var _planet_body: Node3D
var _state_test := false
var _sky_mat: ShaderMaterial
var _kick_demo := ""
var _lights_arg := ""
var _lights_demo := ""
var _walk_demo := false
var _readout_demo := false
var _log_demo := false
var _time_demo := false
var _orbit_demo := ""
var _save_mode := ""
var _save_demo := false
var _stand_test := false


func _ready() -> void:
	_shot = OS.get_environment("AKARI_SHOT") == "1" or OS.get_environment("AKARI_HERO") == "1" or OS.get_environment("AKARI_SIDE") == "1" or OS.get_environment("AKARI_SEAM") == "1"
	var user_args := OS.get_cmdline_user_args()
	_tour = user_args.has("--tour") or user_args.has("--walk") or user_args.has("--film") or user_args.has("--zones") or user_args.has("--bay") or user_args.has("--hull") or user_args.has("--mega") or user_args.has("--atmo") or user_args.has("--interior") or user_args.has("--exterior")
	_title_card = OS.get_environment("AKARI_TITLE") == "1"
	_cabin_view = OS.get_environment("AKARI_CABIN")
	_read_cli()
	_stand_test = user_args.has("--stand-test")
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
	_planet_body = body
	_planet_center = planet.position
	_planet_radius = float(planet.radius)

	var ship := Node3D.new()
	ship.name = "Ship"
	ship.set_script(load("res://scripts/flight/ship_controller.gd"))
	ship.set_meta("flight_active", _shot or _tour or not _cabin_view.is_empty() or not _kick_demo.is_empty() or not _lights_demo.is_empty() or not _lights_arg.is_empty() or not _orbit_demo.is_empty())
	_world.add_child(ship)
	ship.planet_position = planet.position
	ship.planet_radius = planet.radius
	_ship = ship
	if _shot or _tour or not _cabin_view.is_empty() or not _kick_demo.is_empty() or not _lights_demo.is_empty() or not _lights_arg.is_empty() or not _orbit_demo.is_empty():
		_place_for_shot(ship, planet)
	else:
		ship.global_position = chart.spawn
		ship.look_at(planet.position, Vector3.UP)

	var camera := Camera3D.new()
	camera.name = "ChaseCamera"
	camera.set_script(load("res://scripts/flight/chase_camera.gd"))
	camera.ship_path = ship.get_path()
	camera.set_meta("title_hold", not _shot and not _tour and _kick_demo.is_empty() and _lights_demo.is_empty() and _lights_arg.is_empty() and _orbit_demo.is_empty())
	camera.set_meta("planet_center", planet.position)
	camera.set_meta("planet_radius", float(planet.radius))
	_world.add_child(camera)
	if _shot and OS.get_environment("AKARI_HERO") == "1":
		_frame_hero(ship, camera)
	elif _shot and OS.get_environment("AKARI_CLOSEUP") == "1":
		_frame_closeup(ship, camera)
	elif _shot and OS.get_environment("AKARI_SIDE") == "1":
		_frame_side(ship, camera)
	elif _shot and OS.get_environment("AKARI_SEAM") == "1":
		_frame_seam(ship, camera)
	elif not _shot and not _tour and not _stand_test and _cabin_view.is_empty() and _kick_demo.is_empty() and _lights_demo.is_empty() and _lights_arg.is_empty() and _orbit_demo.is_empty():
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
	var inventory_hud = load("res://scripts/ui/inventory_hud.gd").new()
	inventory_hud.name = "InventoryHud"
	add_child(inventory_hud)
	inventory_hud.bind(ship)
	if not _cabin_view.is_empty():
		ship.start_cabin_view(_cabin_view)
	if _kick_demo == "inside":
		ship.hold_seat_flight()
		var seat = ship.get("_cabin")
		if seat and seat.walker and seat.walker.eye:
			seat.walker.pitch = -0.38
			seat.walker.eye.rotation.x = -0.38
	elif _kick_demo == "outside":
		ship.global_rotate(Vector3.UP, PI)
		# Keep the hull in frame so the camera kick stays readable.
		ship.dev_speed_mult = 0.045
	if not _kick_demo.is_empty():
		var kick_demo = load("res://scripts/flight/thrust_demo.gd").new()
		kick_demo.name = "ThrustDemo"
		add_child(kick_demo)
		kick_demo.setup(ship)
	if not _lights_arg.is_empty() or not _lights_demo.is_empty():
		var lit = ship.get("_cabin")
		if lit:
			lit.show_hotbar = false
			if not _lights_arg.is_empty():
				lit.terminal_submit_text("LIGHTS " + _lights_arg.to_upper())
	if not _lights_demo.is_empty():
		var lights_demo = load("res://scripts/flight/lights_demo.gd").new()
		lights_demo.name = "LightsDemo"
		add_child(lights_demo)
		lights_demo.setup(ship)
	if _walk_demo:
		var walked = ship.get("_cabin")
		if walked:
			walked.show_hotbar = false
			if walked.walker:
				walked.walker.locked = false
		var walk_demo = load("res://scripts/flight/walk_demo.gd").new()
		walk_demo.name = "WalkDemo"
		add_child(walk_demo)
		walk_demo.setup(ship)
	if _readout_demo:
		ship.hold_seat_flight()
		var read_seat = ship.get("_cabin")
		if read_seat:
			read_seat.show_hotbar = false
		var readout_demo = load("res://scripts/flight/readout_demo.gd").new()
		readout_demo.name = "ReadoutDemo"
		add_child(readout_demo)
		readout_demo.setup(ship)
	if _time_demo:
		var timed = ship.get("_cabin")
		if timed:
			timed.show_hotbar = false
		var time_demo = load("res://scripts/flight/time_demo.gd").new()
		time_demo.name = "TimeDemo"
		add_child(time_demo)
		time_demo.setup(ship)
	if _log_demo:
		ship.hold_seat_flight()
		var logged = ship.get("_cabin")
		if logged:
			logged.show_hotbar = false
		var log_demo = load("res://scripts/flight/log_demo.gd").new()
		log_demo.name = "LogDemo"
		add_child(log_demo)
		log_demo.setup(ship)
	if not _orbit_demo.is_empty():
		if _orbit_demo != "out":
			ship.hold_seat_flight()
		var orbiting = ship.get("_cabin")
		if orbiting:
			orbiting.show_hotbar = false
		var orbit_demo = load("res://scripts/flight/orbit_demo.gd").new()
		orbit_demo.name = "OrbitDemo"
		add_child(orbit_demo)
		orbit_demo.setup(ship, _orbit_demo == "out")
	var keeper = load("res://scripts/flight/ship_keeper.gd").new()
	keeper.name = "ShipKeeper"
	add_child(keeper)
	keeper.setup(ship, "user://akari_save.json")
	ship.set_keeper(keeper)
	_arm_keeper(keeper)
	if _save_demo:
		ship.hold_seat_flight()
		var saved = ship.get("_cabin")
		if saved:
			saved.show_hotbar = false
		var save_demo = load("res://scripts/flight/save_demo.gd").new()
		save_demo.name = "SaveDemo"
		add_child(save_demo)
		save_demo.setup(ship, _save_mode)
	if _stand_test:
		ship.set_flight_active(true)
		var stand = load("res://test/stand_check.gd").new()
		stand.name = "StandCheck"
		add_child(stand)
		stand.setup(ship)
	if not _cli_at.is_empty():
		dev_teleport(_cli_at)
	_apply_shot_inventory()
	if _cli_door != "":
		_aim_bay_at_planet(_ship)
		var door_cabin = _ship.get("_cabin")
		if door_cabin and door_cabin.has_method("set_bay_pose"):
			door_cabin.snap_view("rear")
			door_cabin.walker.pitch = 0.0
			door_cabin.walker.eye.rotation.x = 0.0
			door_cabin.set_bay_pose(_cli_door)
	if _cli_at.begins_with("mega") or _cli_at.begins_with("atmo"):
		_frame_mega(_cli_at)
	if _tour:
		var args := OS.get_cmdline_user_args()
		if args.has("--mega") or args.has("--atmo"):
			var mega = load("res://scripts/world/mega_tour.gd").new()
			mega.name = "MegaTour"
			add_child(mega)
			mega.setup(_planet_body, ship)
		else:
			# The film tour opens on the exterior. Walk and the inventory tour start inside.
			if args.has("--bay"):
				_aim_bay_at_planet(ship)
			if not args.has("--film"):
				var tour_view := "rear"
				if args.has("--walk"):
					tour_view = "aisle"
				ship.start_cabin_view(tour_view)
			var tour = load("res://scripts/flight/cabin_tour.gd").new()
			tour.name = "CabinTour"
			add_child(tour)
			tour.setup(ship)
	_add_sun_glare(camera, sun_dir)
	_add_dither()
	_update_bounce()
	if OS.get_cmdline_user_args().has("--bench"):
		var bench = load("res://scripts/bench_run.gd").new()
		bench.name = "BenchRun"
		add_child(bench)
		bench.setup(self, ship)
	if OS.get_environment("AKARI_CONSOLE") == "1":
		DevConsole.present()
	_state_test = OS.get_cmdline_user_args().has("--state-test")


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
	material.set_shader_parameter("dither_strength", 0.01)
	material.set_shader_parameter("grain_strength", 0.014)
	material.set_shader_parameter("quantize_steps", 36.0)
	material.set_shader_parameter("vignette", 0.14)
	material.set_shader_parameter("ca_strength", _PostProfile.film_ca())
	rect.material = material
	rect.add_to_group("akari_film")
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
	var lift := 0.05 if _low_sun else 0.1
	var span := 0.18 if _low_sun else 0.34
	_bounce.light_energy = lift + span * near * near


# hot
func _update_sky() -> void:
	if _sky_mat == null or _world == null:
		return
	var origin := _planet_center
	if _ship != null:
		origin = _ship.global_position
	var cam := _world.get_camera_3d()
	if cam != null:
		origin = cam.global_position
	var offset := origin - _planet_center
	var distance := offset.length()
	if distance < 0.001:
		return
	var height := distance - _planet_radius
	var span := _planet_radius * 2.4
	var t := clampf((height - _planet_radius * 0.05) / span, 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	_sky_mat.set_shader_parameter("ground_mix", 1.0 - t)
	_sky_mat.set_shader_parameter("up_dir", offset / distance)


# hot
func _process(delta: float) -> void:
	if _state_test:
		_state_test = false
		var failed: int = load("res://test/test_statechart.gd").run()
		failed += load("res://test/test_atmosphere.gd").run()
		get_tree().quit(failed)
		return
	_update_bounce()
	_update_sky()
	if _tour:
		return
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
	if not _kick_demo.is_empty() or not _lights_demo.is_empty() or _walk_demo or _readout_demo or _log_demo or _time_demo or not _orbit_demo.is_empty() or _save_demo or (not _shot and _cabin_view.is_empty()) or _shot_saved:
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


func _aim_bay_at_planet(ship: Node3D) -> void:
	# The bay opens on +Z. look_at aims -Z, so aim the nose away from Mina.
	var center: Vector3 = _planet.position
	var away := ship.global_position * 2.0 - center
	ship.look_at(away, Vector3.UP)


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


func _frame_exterior(ship: Node3D) -> void:
	var camera := ship.get("_chase") as Camera3D
	if camera == null:
		return
	camera.held = true
	camera.current = true
	var forward := -ship.global_basis.z
	var right := ship.global_basis.x
	camera.fov = 34.0
	camera.global_position = ship.global_position - forward * 8.2 + right * 6.4 + Vector3.UP * 2.2
	camera.look_at(ship.global_position + forward * 5.5 + Vector3.UP * 0.3, Vector3.UP)


func _frame_hero(ship: Node3D, camera: Camera3D) -> void:
	var forward := -ship.global_basis.z
	var right := ship.global_basis.x
	# Low front three-quarter, so the white nose and canopy take the sun.
	_frame_portrait(ship, camera, forward * 7.4 + right * 5.6 + Vector3.UP * 1.7, forward * 0.8, 26.0)


func _frame_mega(mode: String) -> void:
	if _planet_body == null:
		return
	var city := _planet_body.get_node_or_null("MegaCity") as Node3D
	var camera := _ship.get("_chase") as Camera3D
	if city == null or camera == null:
		return
	_ship.global_position = _planet_center + Vector3(0.0, _planet_radius * 8.0, 0.0)
	camera.held = true
	camera.current = true
	var spot := Vector3(16.0, 42.0, 30.0)
	var aim := Vector3(0.0, 8.0, 6.0)
	camera.fov = 36.0
	if mode == "mega-cloud":
		spot = Vector3(8.0, 1.3, 2.0)
		aim = Vector3(-1.0, 7.0, 12.0)
		camera.fov = 48.0
	elif mode == "mega-canyon":
		spot = Vector3(0.25, 3.2, 6.0)
		aim = Vector3(0.4, 14.0, 15.0)
		camera.fov = 54.0
	elif mode == "mega-detail":
		spot = Vector3(-2.4, 6.0, -0.2)
		aim = Vector3(-5.2, 10.0, -1.0)
		camera.fov = 32.0
	elif mode == "atmo-limb":
		spot = Vector3(10.0, 86.0, 34.0)
		aim = Vector3(0.0, -12.0, 0.0)
		camera.fov = 28.0
	elif mode == "atmo-sky":
		spot = Vector3(3.0, 20.0, 16.0)
		aim = Vector3(0.2, 6.0, 12.0)
		camera.fov = 52.0
	elif mode == "atmo-city":
		spot = Vector3(0.25, 3.2, 6.0)
		aim = Vector3(0.4, 14.0, 15.0)
		camera.fov = 50.0
	camera.global_position = city.to_global(spot)
	camera.look_at(city.to_global(aim), city.global_basis.y)


func _frame_seam(ship: Node3D, camera: Camera3D) -> void:
	var right := ship.global_basis.x
	var forward := -ship.global_basis.z
	var aim := ship.global_position + Vector3.UP * 0.42 - forward * 0.05
	_frame_portrait(ship, camera, right * 1.15 + Vector3.UP * 1.35 + forward * 0.15, aim - ship.global_position, 26.0)


func _frame_side(ship: Node3D, camera: Camera3D) -> void:
	var right := ship.global_basis.x
	_frame_portrait(ship, camera, right * 7.6 + Vector3.UP * 1.15, Vector3.UP * 0.15, 24.0)


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
	_dismiss_title()
	if key == "planet" or key == "exterior":
		_ship.dev_leave_cabin()
		_ship.velocity = Vector3.ZERO
		_place_for_shot(_ship, _planet)
		if key == "exterior":
			_frame_exterior(_ship)
		return "tp " + key
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
		_finish_dev_view()
		return "tp cabin"
	if key == "aisle":
		_place_for_shot(_ship, _planet)
		_ship.velocity = Vector3.ZERO
		_ship.start_cabin_view("aisle")
		_finish_dev_view()
		return "tp aisle"
	if key == "rear" or key == "back":
		_place_for_shot(_ship, _planet)
		_ship.velocity = Vector3.ZERO
		_ship.start_cabin_view("rear")
		_finish_dev_view()
		return "tp rear"
	if key == "dash":
		_place_for_shot(_ship, _planet)
		_ship.velocity = Vector3.ZERO
		_ship.start_cabin_view("dash")
		_finish_dev_view()
		return "tp dash"
	if key == "crates":
		_place_for_shot(_ship, _planet)
		_ship.velocity = Vector3.ZERO
		_ship.start_cabin_view("crates")
		_finish_dev_view()
		return "tp crates"
	if key == "locker":
		_place_for_shot(_ship, _planet)
		_ship.velocity = Vector3.ZERO
		_ship.start_cabin_view("locker")
		_finish_dev_view()
		return "tp locker"
	if key == "storage":
		_place_for_shot(_ship, _planet)
		_ship.velocity = Vector3.ZERO
		_ship.start_cabin_view("storage")
		_finish_dev_view()
		return "tp storage"
	if key == "living":
		_place_for_shot(_ship, _planet)
		_ship.velocity = Vector3.ZERO
		_ship.start_cabin_view("living")
		_finish_dev_view()
		return "tp living"
	if key == "bench":
		_place_for_shot(_ship, _planet)
		_ship.velocity = Vector3.ZERO
		_ship.start_cabin_view("bench")
		_finish_dev_view()
		return "tp bench"
	if key == "wide":
		_place_for_shot(_ship, _planet)
		_ship.velocity = Vector3.ZERO
		_ship.start_cabin_view("wide")
		_finish_dev_view()
		return "tp wide"
	return "unknown tp target '%s'" % key


func _dismiss_title() -> void:
	var director := get_node_or_null("TitleDirector")
	if director and director.has_method("abort_for_dev"):
		director.abort_for_dev()


func _finish_dev_view() -> void:
	if _ship == null:
		return
	var cabin = _ship.get("_cabin")
	if cabin and cabin.has_method("release_fixed_view"):
		cabin.release_fixed_view()
	if cabin and cabin.walker and cabin.walker.eye:
		cabin.walker.eye.current = true


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


func _apply_shot_inventory() -> void:
	if _ship == null:
		return
	var cabin = _ship.get("_cabin")
	if cabin == null or cabin.inventory == null:
		return
	var inv = cabin.inventory
	if not _cli_hold.is_empty():
		inv.give(_cli_hold.to_lower(), 1)
	if not _cli_floor.is_empty():
		inv.give(_cli_floor.to_lower(), 1)
		inv.select(0)
		inv.drop_selected()
		cabin.snap_view("floor")
	if _cabin_view == "locker" or _cli_at == "locker":
		cabin.snap_view("locker")
		inv.store("LockerL", "crate", 1)
		inv.store("LockerL", "cartridge", 2)
		inv.open("LockerL")


func _input(event: InputEvent) -> void:
	# The ship sits in the low-res SubViewport, so window keys never reach its _input.
	# Throttle still works because the flight loop polls Input. E and mouse look do not.
	if _world != null:
		_world.push_input(event)


func _arm_keeper(keeper) -> void:
	var args := OS.get_cmdline_user_args()
	var tools := _shot or _tour or _walk_demo or _readout_demo or _log_demo or _time_demo or _stand_test
	tools = tools or not _kick_demo.is_empty() or not _lights_demo.is_empty() or not _lights_arg.is_empty() or not _orbit_demo.is_empty()
	tools = tools or not _cli_shot.is_empty() or args.has("--bench") or args.has("--state-test") or args.has("--stand-test")
	tools = tools or (not _cabin_view.is_empty() and not _save_demo)
	if _save_mode == "write":
		keeper.armed = true
		keeper.wipe()
		return
	if tools:
		keeper.armed = false
		return
	keeper.armed = true
	keeper.load_now()


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
		elif arg == "--hold" and i + 1 < args.size():
			_cli_hold = str(args[i + 1])
			i += 2
		elif arg == "--floor" and i + 1 < args.size():
			_cli_floor = str(args[i + 1])
			i += 2
		elif arg == "--door" and i + 1 < args.size():
			_cli_door = str(args[i + 1]).to_lower()
			i += 2
		elif arg == "--thrust-demo" and i + 1 < args.size():
			_kick_demo = str(args[i + 1])
			i += 2
		elif arg == "--lights" and i + 1 < args.size():
			_lights_arg = str(args[i + 1]).to_lower()
			i += 2
		elif arg == "--lights-demo" and i + 1 < args.size():
			_lights_demo = str(args[i + 1])
			i += 2
		elif arg == "--walk-demo":
			_walk_demo = true
			i += 1
		elif arg == "--readout-demo":
			_readout_demo = true
			i += 1
		elif arg == "--log-demo":
			_log_demo = true
			i += 1
		elif arg == "--time-demo":
			_time_demo = true
			i += 1
		elif arg == "--orbit-demo":
			_orbit_demo = "in"
			if i + 1 < args.size() and not str(args[i + 1]).begins_with("--"):
				_orbit_demo = str(args[i + 1])
				i += 2
			else:
				i += 1
		elif arg == "--save-demo":
			_save_mode = "write"
			_save_demo = true
			if i + 1 < args.size() and not str(args[i + 1]).begins_with("--"):
				_save_mode = str(args[i + 1])
				i += 2
			else:
				i += 1
		else:
			i += 1
	if _kick_demo == "inside" or _log_demo or _time_demo or _orbit_demo == "in" or _save_demo:
		_cabin_view = "seat"
	if _lights_demo == "wide":
		_cabin_view = "wide"
	elif _lights_demo == "inside" or not _lights_arg.is_empty():
		_cabin_view = "seat"
	if _walk_demo:
		_cabin_view = "aisle"
	if _readout_demo:
		_cabin_view = "seat"
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
	elif at == "locker":
		_cabin_view = "locker"
	elif at == "crates":
		_cabin_view = "crates"
	elif at == "living":
		_cabin_view = "living"
	elif at == "bench":
		_cabin_view = "bench"
	elif at == "wide":
		_cabin_view = "wide"
	else:
		_cabin_view = ""


func _run_cli_shot() -> void:
	await DevConsole.capture_screenshot(1.0, false, _cli_shot)
	get_tree().quit()


func _build_environment(sky_colors: Dictionary, sun_dir: Vector3) -> void:
	var high := _PostProfile.high_quality()
	var med := _PostProfile.detailed()
	var low := not med
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.background_energy_multiplier = 1.0
	# Cool teal in the shade. The amber key does the lit side.
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = FlightProfile.SHADE_COLOR
	environment.ambient_light_energy = 0.035 if low else 0.055
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.04
	environment.tonemap_white = 8.5

	# Halation on the sun and bright highlights. Low quality skips it.
	environment.glow_enabled = not low
	environment.glow_normalized = false
	environment.glow_intensity = 0.85 if high else 0.38
	environment.glow_strength = 1.05 if high else 0.55
	environment.glow_bloom = 0.06 if high else 0.0
	environment.glow_hdr_threshold = 1.08 if high else 1.65
	environment.glow_hdr_scale = 2.0
	environment.glow_hdr_luminance_cap = 16.0
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	environment.set_glow_level(0, 0.0)
	environment.set_glow_level(1, 0.35 if high else 0.15)
	environment.set_glow_level(2, 0.55 if high else 0.3)
	environment.set_glow_level(3, 0.7 if high else 0.2)
	environment.set_glow_level(4, 0.45 if high else 0.0)
	environment.set_glow_level(5, 0.22 if high else 0.0)
	environment.set_glow_level(6, 0.08 if high else 0.0)

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
	material.set_shader_parameter("ground_mix", 0.0)
	material.set_shader_parameter("cheap", 0.0 if high else 1.0)
	_sky_mat = material
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
	var low := not _PostProfile.detailed()
	_low_sun = low
	# One hard sun, low and amber: long rims, crisp terminator, no soft PBR wrap.
	var key := DirectionalLight3D.new()
	key.name = "SunLight"
	key.light_color = FlightProfile.SUN_COLOR
	key.light_energy = FlightProfile.SUN_ENERGY_LOW if low else FlightProfile.SUN_ENERGY
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

	# Cool teal on the far side. Low energy so it stays a flat fill, not a second sun.
	var rim := DirectionalLight3D.new()
	rim.name = "CoolRim"
	rim.light_color = FlightProfile.FILL_COLOR
	rim.light_energy = FlightProfile.FILL_ENERGY_LOW if low else FlightProfile.FILL_ENERGY
	rim.light_specular = 0.35
	rim.shadow_enabled = false
	rim.look_at_from_position(-sun_dir + Vector3(0.0, -0.25, 0.0), Vector3.ZERO, Vector3.UP)
	_world.add_child(rim)

	# Mina-blue bounce: a weak fill aimed from the planet at the ship, updated each frame.
	_bounce = DirectionalLight3D.new()
	_bounce.name = "PlanetBounce"
	_bounce.light_color = FlightProfile.FILL_COLOR
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
	core_mat.albedo_color = Color(12.0, 5.2, 1.35, 1.0)
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
	glow_mat.albedo_color = Color(1.0, 0.48, 0.16, 0.16)
	glow.material_override = glow_mat
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	star.add_child(glow)


func _log_features(environment: Environment, _sky_colors: Dictionary) -> void:
	var adapter := ""
	if RenderingServer.has_method("get_video_adapter_name"):
		adapter = str(RenderingServer.get_video_adapter_name())
	print("RENDER adapter=", adapter)
	print(
		"FEATURES quality=%s aces=%s glow=%s ssao=%s ssr=%s sdfgi=%s volfog=%s lut=%s"
		% [
			_PostProfile.quality(),
			environment.tonemap_mode == Environment.TONE_MAPPER_ACES,
			environment.glow_enabled,
			environment.ssao_enabled,
			environment.ssr_enabled,
			environment.sdfgi_enabled,
			environment.volumetric_fog_enabled,
			environment.adjustment_color_correction != null,
		]
	)


