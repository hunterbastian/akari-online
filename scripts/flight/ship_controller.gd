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
var _flames: Array[MeshInstance3D] = []
var _halos: Array[MeshInstance3D] = []
var _trails: Array[MeshInstance3D] = []
var _streaks: CPUParticles3D

const _PostProfile := preload("res://scripts/data/post_profile.gd")


func _ready() -> void:
	_shot = OS.get_environment("AKARI_SHOT") == "1"
	_closeup = OS.get_environment("AKARI_CLOSEUP") == "1" or OS.get_environment("AKARI_SIDE") == "1"
	if has_meta("flight_active"):
		active = bool(get_meta("flight_active"))
	var ship := Ships.get_ship(GameState.ship_id)
	_speeds = FlightProfile.for_speed_stat(float(ship.stats.speed))
	_hull = Node3D.new()
	_hull.name = "Hull"
	_hull.scale = Vector3.ONE * FlightProfile.HULL_SCALE
	add_child(_hull)

	var packed := load("res://assets/models/ship.glb") as PackedScene
	if packed == null:
		push_error("Ship glb failed to import.")
	else:
		var model := packed.instantiate()
		_hull.add_child(model)
		_dress_ship(model)
	_build_flames()
	_build_engine_fx()
	_build_speed_streaks()
	if _PostProfile.high_quality():
		_build_reflection_probe()
		# Keep the ship out of its own probe (layer 2), so the probe sees only space and Mina.
		_set_layer(_hull, 2)


func set_flight_active(on: bool) -> void:
	active = on


func set_demo_fly(on: bool) -> void:
	demo_fly = on


func _input(event: InputEvent) -> void:
	if not active or _shot:
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


const _HULL_PAINT := preload("res://assets/shaders/hull_paint.gdshader")


func _dress_ship(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var mesh := mesh_instance.mesh
		if mesh:
			for surface in mesh.get_surface_count():
				var material := mesh.surface_get_material(surface)
				if material is StandardMaterial3D:
					var painted := _tune_hull(material as StandardMaterial3D)
					if painted:
						mesh.surface_set_material(surface, painted)
	for child in node.get_children():
		_dress_ship(child)


func _tune_hull(material: StandardMaterial3D) -> ShaderMaterial:
	var name := material.resource_name.to_lower()
	material.metallic = 0.16
	material.roughness = 0.76
	if "canopy" in name:
		material.albedo_color = Color(0.07, 0.1, 0.14)
		material.albedo_color = Color(0.04, 0.06, 0.09)
		material.metallic = 0.72
		material.roughness = 0.03
		material.clearcoat_enabled = true
		material.clearcoat = 1.0
		material.clearcoat_roughness = 0.02
	elif "engine" in name or "glow" in name:
		material.metallic = 0.08
		material.roughness = 0.32
		material.emission_enabled = true
		material.emission = Color(0.72, 0.86, 1.0)
		material.emission_energy_multiplier = 6.0
	elif "dark" in name or "line" in name or "intake" in name or "vent" in name:
		material.albedo_color = Color(0.11, 0.11, 0.12)
		material.metallic = 0.4
		material.roughness = 0.42
	elif "accent" in name:
		material.albedo_color = Color(0.22, 0.48, 0.52)
		material.metallic = 0.25
		material.roughness = 0.34
		material.clearcoat_enabled = true
		material.clearcoat = 0.7
		material.clearcoat_roughness = 0.1
	elif "hull" in name or "panel" in name or "fin" in name or "nacelle" in name:
		var paint := ShaderMaterial.new()
		paint.shader = _HULL_PAINT
		paint.set_shader_parameter("base_color", Color(0.843, 0.827, 0.796))
		paint.set_shader_parameter("roughness_base", 0.42 if "panel" in name else 0.34)
		paint.set_shader_parameter("metallic_base", 0.1)
		return paint
	return null


func _build_flames() -> void:
	for anchor in FlightProfile.ENGINE_ANCHORS:
		var flame := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.07
		cone.height = 0.62
		cone.radial_segments = 6
		flame.mesh = cone
		flame.position = anchor
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
		var length := 0.4 + hot * (2.6 if boosting else 1.6)
		plume.visible = hot > 0.03
		plume.scale = Vector3(0.7 + hot * 0.4, length, 0.7 + hot * 0.4)
		plume.position = (plume.get_meta("anchor") as Vector3) + Vector3(0.0, 0.0, 0.1 + length * 0.5)
	if _streaks:
		_streaks.emitting = boosting and velocity.length() > _speeds.cruise * 1.2


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
	for anchor in FlightProfile.ENGINE_ANCHORS:
		# Hot glow at the nozzle.
		var halo := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.62, 0.62)
		halo.mesh = quad
		halo.position = anchor + Vector3(0.0, 0.0, 0.08)
		halo.material_override = _additive(dot, Color(0.55, 0.78, 1.6, 0.6), BaseMaterial3D.BILLBOARD_ENABLED)
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_hull.add_child(halo)
		_halos.append(halo)
		# Short exhaust plume: a tapered additive cone stretched behind the nozzle.
		# A mesh (not particles) so it reads as one smooth streak at any frame rate.
		var plume := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.2
		cone.bottom_radius = 0.015
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
		plume.position = anchor + Vector3(0.0, 0.0, 0.1)
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
