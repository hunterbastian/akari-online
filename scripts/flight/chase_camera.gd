extends Camera3D

## Chase cam from flySpace: behind the nose, look-ahead, fov opens on boost.

@export var ship_path: NodePath

var _ship: Node3D
var _ready_cam := false
var held := false


func _ready() -> void:
	_ship = get_node_or_null(ship_path) as Node3D
	fov = FlightProfile.FOV
	near = 0.12
	far = 7000.0
	held = has_meta("title_hold") and bool(get_meta("title_hold"))
	if held:
		current = false
		return
	current = true
	if _ship:
		_apply(0.0, true)


func release_from_title() -> void:
	held = false
	current = true
	_apply(0.0, true)


func _process(delta: float) -> void:
	if held or _ship == null:
		return
	_apply(minf(delta, FlightProfile.DT_CAP), false)


func _apply(step: float, snap: bool) -> void:
	var boosting: bool = _ship.get("boosting")
	var cam_dist := FlightProfile.CAM_DIST_BOOST if boosting else FlightProfile.CAM_DIST
	var forward := -_ship.global_basis.z
	var desired := _ship.global_position + Vector3.UP * FlightProfile.CAM_HEIGHT - forward * cam_dist
	if snap or not _ready_cam:
		global_position = desired
		_ready_cam = true
	else:
		global_position = global_position.lerp(desired, 1.0 - exp(-FlightProfile.CAM_CHASE * step))
	var aim := _ship.global_position + forward * FlightProfile.CAM_LOOK_AHEAD
	look_at(aim, Vector3.UP)
	if snap:
		fov = FlightProfile.FOV
		return
	var target_fov := FlightProfile.FOV_BOOST if boosting else FlightProfile.FOV
	fov = FlightProfile.damp(fov, target_fov, FlightProfile.FOV_DAMP, step)
