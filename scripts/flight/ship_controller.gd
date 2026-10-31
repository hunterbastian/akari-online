extends Node3D

## Space flight with the web flySpace constants. Keyboard and mouse only.

var velocity := Vector3.ZERO
var boosting := false
var thrust := 0.0
var planet_position := Vector3.ZERO
var planet_radius := 24.0

var _speeds := {}
var _bank := 0.0
var _mouse_dx := 0.0
var _mouse_dy := 0.0
var _shot := false
var _closeup := false
var active := true
var demo_fly := false
var _hull: Node3D
var _model: Node
var _cabin
var _chase: Camera3D
var _shell: Array[GeometryInstance3D] = []
var _paints: Array[ShaderMaterial] = []
var _engine_anchors: Array[Vector3] = []
var walking := false
var _flames: Array[MeshInstance3D] = []
var _halos: Array[MeshInstance3D] = []
var _trails: Array[MeshInstance3D] = []
var _streaks: CPUParticles3D

const _PostProfile := preload("res://scripts/data/post_profile.gd")
const _Dress := preload("res://scripts/flight/jumpship_dress.gd")
const _Cabin := preload("res://scripts/flight/cabin_interior.gd")
const _FX := 2.5


func _ready() -> void:
	_shot = OS.get_environment("AKARI_SHOT") == "1"
	_closeup = OS.get_environment("AKARI_CLOSEUP") == "1" or OS.get_environment("AKARI_SIDE") == "1" or OS.get_environment("AKARI_HERO") == "1"
	if has_meta("flight_active"):
		active = bool(get_meta("flight_active"))
	var ship := Ships.get_ship(GameState.ship_id)
	_speeds = FlightProfile.for_speed_stat(float(ship.stats.speed))
	_hull = Node3D.new()
	_hull.name = "Hull"
	_hull.scale = Vector3.ONE * FlightProfile.JUMPSHIP_SCALE
	add_child(_hull)

	var packed := load("res://assets/ships/jumpship.glb") as PackedScene
	if packed == null:
		push_error("Jumpship glb failed to import.")
	else:
		_model = packed.instantiate()
		_hull.add_child(_model)
		_Dress.prepare(_model)
		var high := _PostProfile.high_quality()
		_paints = _Dress.paint(_model, high)
		_shell = _Dress.shell_nodes(_model)
		_engine_anchors = _Dress.engine_anchors(_model)
	if _engine_anchors.is_empty():
		_engine_anchors = FlightProfile.ENGINE_ANCHORS.duplicate()
	_build_flames()
	_build_engine_fx()
	_build_speed_streaks()
	for child in _hull.get_children():
		_set_layer(child, 2)
	_cabin = _Cabin.new()
	_cabin.name = "Cabin"
	_cabin.scale = Vector3.ONE / FlightProfile.JUMPSHIP_SCALE
	_hull.add_child(_cabin)
	_cabin.build(FlightProfile.JUMPSHIP_SCALE, _PostProfile.high_quality())
	_paints.append_array(_cabin.paints)
	if _PostProfile.high_quality():
		_build_reflection_probe()
	_update_cabin()


func set_flight_active(on: bool) -> void:
	active = on


func set_demo_fly(on: bool) -> void:
	demo_fly = on


func set_chase_camera(camera: Camera3D) -> void:
	_chase = camera


func set_cabin_controls(controls: Node) -> void:
	if _cabin and _cabin.walker:
		_cabin.walker.controls = controls


func near_seat() -> bool:
	return walking and _cabin != null and _cabin.walker.near_point(_cabin.seat_point, _cabin.sit_reach)


func toggle_seat() -> void:
	if not active or _shot:
		return
	if not walking:
		_enter_cabin()
	elif near_seat():
		_exit_cabin()


func start_cabin_view(mode: String) -> void:
	active = true
	velocity = Vector3.ZERO
	thrust = 0.0
	boosting = false
	_enter_cabin()
	if _cabin:
		_cabin.snap_view(mode)


func _enter_cabin() -> void:
	walking = true
	_set_shell_hidden(true)
	if _cabin:
		_cabin.set_walking(true)
		var body = _cabin.walker
		body.eye_height = _cabin.standing_eye
		body.position = Vector3(_cabin.aisle_point.x, body.floor_y, _cabin.aisle_point.z)
		body.set_enabled(true)
	if _chase:
		_chase.current = false
	if _streaks:
		_streaks.emitting = false
	if DisplayServer.get_name() != "headless" and OS.get_environment("AKARI_CABIN").is_empty():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _exit_cabin() -> void:
	walking = false
	if _cabin:
		_cabin.walker.set_enabled(false)
		_cabin.set_walking(false)
	_set_shell_hidden(false)
	if _chase:
		_chase.current = true


func _set_shell_hidden(hidden: bool) -> void:
	for part in _shell:
		part.visible = not hidden


func _input(event: InputEvent) -> void:
	if not active or _shot:
		return
	if event.is_action_pressed("interact"):
		toggle_seat()
		return
	if walking:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if DisplayServer.get_name() != "headless":
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and _cabin:
			_cabin.walker.add_look(event.relative)
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_dx += event.relative.x
		_mouse_dy += event.relative.y


func _process(delta: float) -> void:
	if not active:
		return
	var step := minf(delta, FlightProfile.DT_CAP)
	if walking:
		_hold_course(step)
		return
	var yaw := -_mouse_dx * FlightProfile.MOUSE_YAW
	var pitch := _mouse_dy * FlightProfile.MOUSE_PITCH
	_mouse_dx = 0.0
	_mouse_dy = 0.0
	if Input.is_action_pressed("yaw_left"):
		yaw += FlightProfile.KEY_YAW_RATE * step
	if Input.is_action_pressed("yaw_right"):
		yaw -= FlightProfile.KEY_YAW_RATE * step
	if _shot and not _closeup:
		yaw += 0.05 * step

	rotate_object_local(Vector3.UP, yaw)
	rotate_object_local(Vector3.RIGHT, pitch)
	var euler := basis.get_euler(EULER_ORDER_YXZ)
	euler.x = clampf(euler.x, -FlightProfile.PITCH_LIMIT, FlightProfile.PITCH_LIMIT)
	euler.z = 0.0
	basis = Basis.from_euler(euler, EULER_ORDER_YXZ)

	var target_bank := clampf(-yaw * FlightProfile.BANK_YAW_SCALE, -FlightProfile.BANK_LIMIT, FlightProfile.BANK_LIMIT)
	_bank = FlightProfile.damp(_bank, target_bank, FlightProfile.BANK_DAMP, step)
	if _hull:
		_hull.rotation.z = _bank

	var forward := -global_basis.z
	boosting = Input.is_action_pressed("boost")
	var throttle := 0.0
	if Input.is_action_pressed("throttle_forward") or (_shot and not _closeup) or demo_fly:
		throttle += 1.0
	if Input.is_action_pressed("throttle_back"):
		throttle -= 1.0
	thrust = maxf(0.0, throttle) * (1.0 if boosting else 0.65)

	var speed := 0.0
	if throttle > 0.0:
		speed = _speeds.boost if boosting else _speeds.cruise
	elif throttle < 0.0:
		speed = -_speeds.cruise * FlightProfile.REVERSE_SCALE

	if throttle != 0.0:
		var desired := forward * speed
		velocity = velocity.lerp(desired, 1.0 - exp(-FlightProfile.THROTTLE_LERP * step))
	else:
		velocity *= exp(-FlightProfile.COAST_DRAG * step)

	if Input.is_action_pressed("lift"):
		velocity.y += FlightProfile.VERTICAL_ACCEL * step
	if Input.is_action_pressed("drop"):
		velocity.y -= FlightProfile.VERTICAL_ACCEL * step

	global_position += velocity * step
	_keep_off_star()
	_keep_off_planet()
	_update_flames()
	_update_cabin()


func _hold_course(step: float) -> void:
	# Autopilot: keep the velocity the ship had when the pilot stood up. No new input, no drag.
	_mouse_dx = 0.0
	_mouse_dy = 0.0
	_bank = FlightProfile.damp(_bank, 0.0, FlightProfile.BANK_DAMP, step)
	if _hull:
		_hull.rotation.z = _bank
	global_position += velocity * step
	_keep_off_star()
	_keep_off_planet()
	_update_flames()
	_update_cabin()


func _update_cabin() -> void:
	var offset := planet_position - global_position
	var distance := maxf(offset.length(), 0.001)
	var toward := offset / distance
	var near := clampf(1.0 - (distance - planet_radius) / (planet_radius * 8.0), 0.0, 1.0)
	var strength := 0.05 + 0.24 * near * near
	for material in _paints:
		material.set_shader_parameter("bounce_dir", toward)
		material.set_shader_parameter("bounce_strength", strength)
	if _cabin:
		var ship := Ships.get_ship(GameState.ship_id)
		var mina_range := maxf(distance - planet_radius, 0.0)
		_cabin.update_readouts(velocity.length(), thrust, mina_range, str(ship.name))


func _keep_off_star() -> void:
	var distance := global_position.length()
	if distance >= FlightProfile.STAR_CLEARANCE or distance < 0.001:
		return
	global_position = global_position.normalized() * FlightProfile.STAR_CLEARANCE
	var inward := velocity.dot(global_position) / FlightProfile.STAR_CLEARANCE
	if inward < 0.0:
		velocity += global_position * (-inward / FlightProfile.STAR_CLEARANCE)


func _keep_off_planet() -> void:
	var offset := global_position - planet_position
	var distance := offset.length()
	var limit := planet_radius + FlightProfile.PLANET_CLEARANCE
	if distance >= limit or distance < 0.001:
		return
	var normal := offset / distance
	global_position = planet_position + normal * limit
	var into := velocity.dot(normal)
	if into < 0.0:
		velocity -= normal * into


func _build_flames() -> void:
	for anchor in _engine_anchors:
		var flame := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.07 * _FX
		cone.height = 0.62 * _FX
		cone.radial_segments = 6
		flame.mesh = cone
		flame.position = anchor + Vector3(0.0, 0.0, 0.35 * _FX)
		flame.rotation.x = PI / 2.0
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		material.albedo_color = Color(0.72, 0.88, 1.45, 0.62)
		flame.material_override = material
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_hull.add_child(flame)
		_flames.append(flame)


func _update_flames() -> void:
	var hot := thrust
	for flame in _flames:
		flame.scale = Vector3(1.0, 0.28 + hot * 1.35, 1.0)
		var material := flame.material_override as StandardMaterial3D
		if material:
			# Above the glow threshold at full thrust, so only engines and the sun bloom.
			var energy := 1.2 + hot * 5.0
			material.albedo_color = Color(energy * 0.42, energy * 0.7, energy, 0.45 + hot * 0.4)
	for halo in _halos:
		halo.scale = Vector3.ONE * (0.55 + hot * 0.75)
		var halo_material := halo.material_override as StandardMaterial3D
		if halo_material:
			halo_material.albedo_color = Color(0.55, 0.78, 1.6, 0.25 + hot * 0.55)
	for plume in _trails:
		var length := (0.4 + hot * (2.6 if boosting else 1.6)) * _FX
		plume.visible = hot > 0.03
		plume.scale = Vector3(0.7 + hot * 0.4, length, 0.7 + hot * 0.4)
		plume.position = (plume.get_meta("anchor") as Vector3) + Vector3(0.0, 0.0, 0.1 + length * 0.5)
	if _streaks:
		_streaks.emitting = not walking and boosting and velocity.length() > _speeds.cruise * 1.2


func _soft_dot() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture


func _additive(texture: Texture2D, color: Color, billboard: int) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_texture = texture
	material.albedo_color = color
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = billboard
	return material


func _build_engine_fx() -> void:
	var dot := _soft_dot()
	var high := _PostProfile.high_quality()
	for anchor in _engine_anchors:
		# Hot glow at the nozzle.
		var halo := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.62, 0.62) * _FX
		halo.mesh = quad
		halo.position = anchor + Vector3(0.0, 0.0, 0.08 * _FX)
		halo.material_override = _additive(dot, Color(0.55, 0.78, 1.6, 0.6), BaseMaterial3D.BILLBOARD_ENABLED)
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_hull.add_child(halo)
		_halos.append(halo)
		# Short exhaust plume: a tapered additive cone stretched behind the nozzle.
		# A mesh (not particles) so it reads as one smooth streak at any frame rate.
		var plume := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.2 * _FX
		cone.bottom_radius = 0.015 * _FX
		cone.height = 1.0
		cone.radial_segments = 10 if high else 6
		cone.rings = 1
		cone.cap_top = false
		cone.cap_bottom = false
		plume.mesh = cone
		var fade := GradientTexture2D.new()
		var fade_ramp := Gradient.new()
		fade_ramp.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
		fade_ramp.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
		fade.gradient = fade_ramp
		fade.fill_from = Vector2(0.0, 0.0)
		fade.fill_to = Vector2(0.0, 1.0)
		fade.width = 4
		fade.height = 64
		var plume_mat := _additive(fade, Color(0.5, 0.74, 1.5, 0.5), BaseMaterial3D.BILLBOARD_DISABLED)
		plume_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		plume.material_override = plume_mat
		# Cylinder axis is +Y; tip it so the wide top sits at the nozzle and the tip trails along +Z.
		plume.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
		plume.position = anchor + Vector3(0.0, 0.0, 0.1 * _FX)
		plume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		plume.set_meta("anchor", anchor)
		_hull.add_child(plume)
		_trails.append(plume)


func _build_speed_streaks() -> void:
	# Thin lines rushing past the camera while boosting.
	_streaks = CPUParticles3D.new()
	_streaks.name = "SpeedStreaks"
	_streaks.emitting = false
	_streaks.local_coords = true
	_streaks.amount = 70 if _PostProfile.high_quality() else 24
	_streaks.lifetime = 0.32
	_streaks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_streaks.emission_box_extents = Vector3(7.0, 4.5, 10.0)
	_streaks.position = Vector3(0.0, 1.0, -4.0)
	_streaks.direction = Vector3(0, 0, 1)
	_streaks.spread = 0.0
	_streaks.initial_velocity_min = 80.0
	_streaks.initial_velocity_max = 110.0
	_streaks.gravity = Vector3.ZERO
	_streaks.particle_flag_align_y = true
	var line := BoxMesh.new()
	line.size = Vector3(0.018, 2.2, 0.018)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(0.7, 0.85, 1.0, 0.35)
	line.material = material
	_streaks.mesh = line
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	_streaks.color_ramp = ramp
	_streaks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_streaks.layers = 1 << 1
	add_child(_streaks)


func _build_reflection_probe() -> void:
	# Follows the ship so the canopy and lacquer reflect Mina and the sun, not just the sky.
	var probe := ReflectionProbe.new()
	probe.name = "ShipReflections"
	probe.update_mode = ReflectionProbe.UPDATE_ALWAYS
	probe.size = Vector3(40, 40, 40)
	probe.max_distance = 2000.0
	probe.box_projection = false
	probe.interior = false
	probe.enable_shadows = false
	probe.mesh_lod_threshold = 4.0
	probe.cull_mask = 1
	add_child(probe)


func _set_layer(node: Node, layer: int) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = 1 << (layer - 1)
	for child in node.get_children():
		_set_layer(child, layer)
