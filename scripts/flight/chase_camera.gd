extends Camera3D

## Chase cam from flySpace: behind the nose, look-ahead, fov opens on boost.

@export var ship_path: NodePath

var _ship: Node3D
var _ready_cam := false
var held := false
var _planet_bias := Vector3.ZERO

const PLANET_LOOK_BIAS := 0.2
const PLANET_LOOK_RANGE := 6.0


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
	# Lean the view a little toward Mina when she is close and ahead, so she sits in frame more.
	var target_bias := Vector3.ZERO
	if has_meta("planet_center"):
		var center: Vector3 = get_meta("planet_center")
		var radius := float(get_meta("planet_radius", 24.0))
		var to_planet := center - global_position
		var distance := to_planet.length()
		var ahead := to_planet.normalized().dot(forward)
		if distance < radius * PLANET_LOOK_RANGE and ahead > -0.1:
			var reach := clampf(1.0 - distance / (radius * PLANET_LOOK_RANGE), 0.0, 1.0)
			var weight := PLANET_LOOK_BIAS * smoothstep(0.0, 0.35, reach) * smoothstep(-0.1, 0.3, ahead)
			target_bias = (to_planet.normalized() - forward) * FlightProfile.CAM_LOOK_AHEAD * weight
	if snap:
		_planet_bias = target_bias
	else:
		_planet_bias = _planet_bias.lerp(target_bias, 1.0 - exp(-2.0 * step))
	look_at(aim + _planet_bias, Vector3.UP)
	if snap:
		fov = FlightProfile.FOV
		return
	var target_fov := FlightProfile.FOV_BOOST if boosting else FlightProfile.FOV
	fov = FlightProfile.damp(fov, target_fov, FlightProfile.FOV_DAMP, step)
