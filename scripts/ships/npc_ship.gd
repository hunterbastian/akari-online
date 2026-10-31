extends Node3D

## A kit ship on a slow orbit. Derelicts drift and flicker instead of holding a tidy path.

var orbit_center := Vector3.ZERO
var orbit_radius := 40.0
var orbit_rate := 0.05
var orbit_phase := 0.0
var orbit_lift := 0.0
var hold := false
var derelict := false
var planet_center := Vector3.ZERO
var _flicker: MeshInstance3D
var _phase := 0.0


func setup(center: Vector3, radius: float, rate: float, phase: float, lift: float, is_derelict: bool, planet: Vector3) -> void:
	orbit_center = center
	orbit_radius = radius
	orbit_rate = rate
	orbit_phase = phase
	orbit_lift = lift
	derelict = is_derelict
	planet_center = planet
	_flicker = find_child("Flicker", true, false) as MeshInstance3D
	_apply(0.0)


func _process(delta: float) -> void:
	_apply(delta)


func _apply(delta: float) -> void:
	if not hold:
		orbit_phase += orbit_rate * delta
	var flat := Vector3(cos(orbit_phase) * orbit_radius, sin(orbit_phase * 2.0) * orbit_lift, sin(orbit_phase) * orbit_radius)
	global_position = orbit_center + flat
	if not derelict:
		var ahead := global_position + Vector3(-sin(orbit_phase), 0.0, cos(orbit_phase))
		if ahead.distance_squared_to(global_position) > 0.001:
			look_at(ahead, Vector3.UP)
	else:
		rotate_object_local(Vector3.UP, delta * 0.05)
	_bounce()
	_blink(delta)


func _bounce() -> void:
	var hull := get_node_or_null("Hull") as MeshInstance3D
	if hull == null or hull.mesh == null:
		return
	var offset := planet_center - global_position
	if offset.length_squared() < 0.001:
		return
	var toward := offset.normalized()
	var mesh := hull.mesh
	for surface in mesh.get_surface_count():
		var material := mesh.surface_get_material(surface)
		if material is ShaderMaterial:
			material.set_shader_parameter("bounce_dir", toward)


func _blink(delta: float) -> void:
	if _flicker == null:
		return
	_phase += delta
	var pulse := 0.35 + 0.65 * absf(sin(_phase * 9.0 + float(get_meta("seed", 0)) * 0.01))
	if fmod(_phase, 1.6) > 1.35:
		pulse = 0.04
	var material := _flicker.material_override as StandardMaterial3D
	if material:
		material.albedo_color = Color(1.8 * pulse, 0.45 * pulse, 0.12 * pulse, 1.0)
