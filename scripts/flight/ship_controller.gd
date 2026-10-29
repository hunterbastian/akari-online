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
var _hull: Node3D
var _flames: Array[MeshInstance3D] = []


func _ready() -> void:
	_shot = OS.get_environment("AKARI_SHOT") == "1"
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
		_hull.add_child(packed.instantiate())
	_build_flames()


func _input(event: InputEvent) -> void:
	if _shot:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_dx += event.relative.x
		_mouse_dy += event.relative.y


func _process(delta: float) -> void:
	var step := minf(delta, FlightProfile.DT_CAP)
	var yaw := -_mouse_dx * FlightProfile.MOUSE_YAW
	var pitch := _mouse_dy * FlightProfile.MOUSE_PITCH
	_mouse_dx = 0.0
	_mouse_dy = 0.0
	if Input.is_action_pressed("yaw_left"):
		yaw += FlightProfile.KEY_YAW_RATE * step
	if Input.is_action_pressed("yaw_right"):
		yaw -= FlightProfile.KEY_YAW_RATE * step
	if _shot:
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
	if Input.is_action_pressed("throttle_forward") or _shot:
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


func _build_flames() -> void:
	for anchor in FlightProfile.ENGINE_ANCHORS:
		var flame := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.09
		cone.height = 1.05
		cone.radial_segments = 6
		flame.mesh = cone
		flame.position = anchor
		flame.rotation.x = PI / 2.0
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		material.albedo_color = Color.html("#e07a48")
		material.albedo_color.a = 0.12
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
			material.albedo_color.a = 0.06 + hot * 0.5
