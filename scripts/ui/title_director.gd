extends Node

## Destiny-style title: a slow drift past Mina, then a blend into the chase camera.

var ship: Node3D
var chase: Camera3D
var planet_center: Vector3
var planet_radius: float
var sun_dir: Vector3

var _camera: Camera3D
var _card: CanvasLayer
var _dust: CPUParticles3D
var _time := 0.0
var _blend := 0.0
var _transition := false
var _finished := false
var _auto := false


func setup(flight_ship: Node3D, chase_camera: Camera3D, center: Vector3, radius: float, light_dir: Vector3) -> void:
	ship = flight_ship
	chase = chase_camera
	planet_center = center
	planet_radius = radius
	sun_dir = light_dir
	_auto = OS.get_environment("AKARI_TITLE_PLAY") == "1"
	_build_camera()
	_build_dust()
	_park_ship()
	_card = load("res://scripts/ui/title_card.gd").new()
	_card.name = "Title"
	add_child(_card)
	_apply_title_pose(0.0)


func _process(delta: float) -> void:
	if _finished:
		return
	_time += delta
	if not _transition:
		_apply_title_pose(_time)
		if _auto and _time > 3.4:
			begin()
		return
	_blend = minf(_blend + delta / 1.85, 1.0)
	var eased := _blend * _blend * (3.0 - 2.0 * _blend)
	var title_position := _title_position(_time)
	var chase_position := _chase_position()
	_camera.global_position = title_position.lerp(chase_position, eased)
	var title_aim := planet_center
	var chase_aim := _chase_aim()
	_camera.look_at(title_aim.lerp(chase_aim, eased), Vector3.UP)
	_camera.fov = lerpf(42.0, FlightProfile.FOV, eased)
	if _card and _card.has_method("set_dismiss"):
		_card.set_dismiss(_blend)
	if _blend >= 1.0:
		_finish()


func _unhandled_input(event: InputEvent) -> void:
	if _transition or _time < 0.45:
		return
	var pressed := false
	if event is InputEventMouseButton and event.pressed:
		pressed = true
	elif event is InputEventKey and event.pressed and not event.echo:
		pressed = true
	if pressed:
		begin()


func begin() -> void:
	if _transition:
		return
	_transition = true
	_blend = 0.0


func _finish() -> void:
	_finished = true
	_camera.current = false
	if _dust:
		_dust.emitting = false
		_dust.visible = false
	if chase and chase.has_method("release_from_title"):
		chase.release_from_title()
	if ship and ship.has_method("set_flight_active"):
		ship.set_flight_active(true)
		if _auto and ship.has_method("set_demo_fly"):
			ship.set_demo_fly(true)
	if _card:
		_card.visible = false


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "TitleCamera"
	_camera.current = true
	_camera.fov = 42.0
	_camera.near = 0.12
	_camera.far = 7000.0
	add_child(_camera)


func _build_dust() -> void:
	_dust = CPUParticles3D.new()
	_dust.name = "Dust"
	_dust.amount = 10
	_dust.lifetime = 8.0
	_dust.preprocess = 3.0
	_dust.explosiveness = 0.0
	_dust.local_coords = true
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust.emission_box_extents = Vector3(2.0, 1.5, 1.0)
	_dust.direction = Vector3(0.08, -0.02, 0.02)
	_dust.spread = 18.0
	_dust.gravity = Vector3.ZERO
	_dust.initial_velocity_min = 0.05
	_dust.initial_velocity_max = 0.16
	_dust.scale_amount_min = 0.004
	_dust.scale_amount_max = 0.01
	var mesh := SphereMesh.new()
	mesh.radius = 0.08
	mesh.height = 0.16
	mesh.radial_segments = 6
	mesh.rings = 3
	_dust.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.82, 0.88, 0.96, 0.16)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_dust.mesh.material = material
	_camera.add_child(_dust)
	# Lower-left of the 42° frame so motes stay off the wordmark and the parked ship.
	_dust.position = Vector3(-13.5, -4.6, -26.0)


func _park_ship() -> void:
	var right := sun_dir.cross(Vector3.UP).normalized()
	ship.global_position = planet_center + right * planet_radius * 1.55 + Vector3.UP * planet_radius * 0.08
	var ahead := -right.cross(Vector3.UP).normalized()
	if ahead.length_squared() < 0.01:
		ahead = Vector3.FORWARD
	ship.look_at(ship.global_position + ahead, Vector3.UP)


func _apply_title_pose(time: float) -> void:
	_camera.global_position = _title_position(time)
	_camera.look_at(planet_center, Vector3.UP)
	_camera.fov = 42.0


func _title_position(time: float) -> Vector3:
	var right := sun_dir.cross(Vector3.UP).normalized()
	var up := right.cross(sun_dir).normalized()
	var drift := time * 0.045
	var look := (sun_dir * cos(deg_to_rad(16.0)) - up * sin(deg_to_rad(16.0)) + right * 0.12).normalized()
	look = look.rotated(Vector3.UP, drift)
	return planet_center - look * planet_radius * 2.85


func _chase_position() -> Vector3:
	var forward := -ship.global_basis.z
	return ship.global_position + Vector3.UP * FlightProfile.CAM_HEIGHT - forward * FlightProfile.CAM_DIST


func _chase_aim() -> Vector3:
	var forward := -ship.global_basis.z
	return ship.global_position + forward * FlightProfile.CAM_LOOK_AHEAD
