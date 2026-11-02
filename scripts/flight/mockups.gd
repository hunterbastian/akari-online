extends Node

## Throwaway prototypes. --mock boot, bay, or entry. Not part of the real flight loop.

const _HEAT := preload("res://assets/shaders/entry_heat.gdshader")

var _kind := ""
var _ship: Node3D
var _cabin
var _time := 0.0
var _eye_base := Vector3.ZERO
var _heat: ShaderMaterial
var _boot_n := 0
var _boot_wait := 0.12

const _BOOT := "AKARI OS\nMEM OK\nCABIN SEAL\nDRIVE STBY\nMINA LOCK\n> TYPE HELP"


func setup(kind: String, ship: Node3D, planet_center: Vector3, planet_radius: float) -> void:
	_kind = kind
	_ship = ship
	_cabin = ship.get("_cabin")
	if _kind == "boot" and _cabin and _cabin.has_method("present_boot"):
		_cabin.present_boot("", "_")
	elif _kind == "bay":
		_park(planet_center, planet_radius, 3.1, false)
		var main := get_parent()
		if main and main.has_method("_aim_bay_at_planet"):
			main._aim_bay_at_planet(_ship)
		if _cabin and _cabin.has_method("snap_view"):
			_cabin.snap_view("rear")
		if _cabin and _cabin.has_method("pulse_bay"):
			_cabin.pulse_bay()
	elif _kind == "entry":
		_park(planet_center, planet_radius, 2.3, true)
		if _cabin and _cabin.has_method("snap_view"):
			_cabin.snap_view("seat")
		_add_heat()
		if _cabin and _cabin.walker and _cabin.walker.eye:
			_eye_base = _cabin.walker.eye.position


func _park(center: Vector3, radius: float, radii: float, nose_in: bool) -> void:
	var approach := (_ship.global_position - center).normalized()
	_ship.global_position = center + approach * radius * radii
	if nose_in:
		_ship.look_at(center, Vector3.UP)
	else:
		var away := _ship.global_position * 2.0 - center
		_ship.look_at(away, Vector3.UP)


func _process(delta: float) -> void:
	_time += delta
	if _kind == "boot":
		_type_boot(delta)
	elif _kind == "entry":
		_shake()
	var limit := 6.5 if _kind == "boot" else 4.5
	if _time < limit:
		return
	if OS.get_cmdline_user_args().has("--shot"):
		return
	get_tree().quit()


func _type_boot(delta: float) -> void:
	if _cabin == null:
		return
	_boot_wait -= delta
	if _boot_n < _BOOT.length() and _boot_wait <= 0.0:
		_boot_n += 1
		var step := _BOOT.substr(_boot_n - 1, 1)
		_boot_wait = 0.2 if step == "\n" else 0.05
	var shown := _BOOT.substr(0, _boot_n)
	var split := shown.rfind("\n")
	var body := ""
	var line := shown
	if split >= 0:
		body = shown.substr(0, split)
		line = shown.substr(split + 1)
	var cursor := "_"
	if _boot_n >= _BOOT.length() and fmod(_time, 1.0) >= 0.55:
		cursor = ""
	_cabin.present_boot(body, line + cursor)


func _shake() -> void:
	if _heat:
		_heat.set_shader_parameter("u_time", _time)
	if _cabin == null or _cabin.walker == null or _cabin.walker.eye == null:
		return
	var eye: Camera3D = _cabin.walker.eye
	var kick := 0.014
	eye.position = _eye_base + Vector3(sin(_time * 31.0) * kick, cos(_time * 23.0) * kick * 0.8, 0.0)
	eye.rotation.z = sin(_time * 19.0) * 0.008


func _add_heat() -> void:
	if _cabin == null:
		return
	var scale: float = float(_cabin.get("_scale"))
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "EntryHeat"
	var quad := QuadMesh.new()
	quad.size = Vector2(2.15, 1.05) * scale
	mesh_instance.mesh = quad
	mesh_instance.position = Vector3(0.0, 1.05, -3.9) * scale
	mesh_instance.rotation.x = 0.1
	_heat = ShaderMaterial.new()
	_heat.shader = _HEAT
	mesh_instance.material_override = _heat
	mesh_instance.layers = 1 << 2
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cabin.add_child(mesh_instance)
