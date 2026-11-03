extends ColorRect

## Pushes the sun, the cabin eye, and the focus ray into the film pass.
## Process stays off on the modern look.

const _Look := preload("res://scripts/data/sixth_look.gd")

var _view: SubViewport
var _sun := Vector3.ZERO
var _planet_center := Vector3.ZERO
var _planet_radius := 24.0
var _ship: Node3D
var _mat: ShaderMaterial


func setup(view: SubViewport, sun_position: Vector3, planet_center: Vector3, planet_radius: float, ship: Node3D, material: ShaderMaterial) -> void:
	_view = view
	_sun = sun_position
	_planet_center = planet_center
	_planet_radius = planet_radius
	_ship = ship
	_mat = material
	sync()


func sync() -> void:
	set_process(_Look.active)
	if _Look.active and is_inside_tree():
		_process(0.0)


# hot
func _process(_delta: float) -> void:
	if _mat == null or _view == null:
		return
	var camera := _view.get_camera_3d()
	var cabin := 0.0
	var on := 0.0
	var uv := Vector2(2.0, 2.0)
	var size_x := float(_view.size.x)
	var size_y := float(_view.size.y)
	if camera != null:
		if camera.is_in_group("cabin_eye"):
			cabin = 1.0
		if size_y > 1.0 and not camera.is_position_behind(_sun):
			var screen := camera.unproject_position(_sun)
			if screen.x >= 0.0 and screen.y >= 0.0 and screen.x <= size_x and screen.y <= size_y:
				if not _eclipsed(camera.global_position):
					on = 1.0
					uv = Vector2(screen.x / size_x, screen.y / size_y)
	var dof := _Look.dof * (1.0 - cabin)
	_mat.set_shader_parameter("pixel_size", Vector2(1.0 / maxf(size_x, 1.0), 1.0 / maxf(size_y, 1.0)))
	_mat.set_shader_parameter("sun_uv", uv)
	_mat.set_shader_parameter("sun_on", on)
	_mat.set_shader_parameter("cabin", cabin)
	_mat.set_shader_parameter("dof_strength", dof)
	_mat.set_shader_parameter("planet_pos", _planet_center)
	_mat.set_shader_parameter("planet_radius", _planet_radius)
	if camera == null:
		return
	_mat.set_shader_parameter("cam_pos", camera.global_position)
	_mat.set_shader_parameter("cam_fwd", -camera.global_basis.z)
	_mat.set_shader_parameter("cam_right", camera.global_basis.x)
	_mat.set_shader_parameter("cam_up", camera.global_basis.y)
	_mat.set_shader_parameter("cam_fov", camera.fov)
	var focus := _planet_center
	if _ship != null:
		focus = _ship.global_position
	_mat.set_shader_parameter("focus_pos", focus)


func _eclipsed(origin: Vector3) -> bool:
	var to_sun := (_sun - origin).normalized()
	var oc := _planet_center - origin
	var along := oc.dot(to_sun)
	if along < 0.0:
		return false
	var closest := oc.length_squared() - along * along
	return closest < _planet_radius * _planet_radius * 1.02
