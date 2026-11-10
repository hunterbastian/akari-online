extends Camera3D

## First-person float outside the bay. The parent is the ship, so the tether
## is in ship meters and an orbit carries the pilot along.

const _MOTION := preload("res://scripts/flight/eva_motion.gd")

var motion = _MOTION.new()
var yaw := 0.0
var pitch := 0.0
var active := false
var script_wish := Vector3.ZERO
var script_yaw := 0.0
var _wish := Vector3.ZERO


func _ready() -> void:
	name = "EvaPilot"
	fov = 64.0
	near = 0.05
	far = 7000.0
	current = false
	cull_mask &= ~(1 << 2)


func add_look(relative: Vector2) -> void:
	yaw -= relative.x * 0.0022
	pitch = clampf(pitch - relative.y * 0.0016, -1.05, 1.05)


func launch(at: Vector3, velocity: Vector3, face_yaw: float, face_pitch: float) -> void:
	motion.pos = at
	motion.vel = velocity
	motion.roll = 0.0
	yaw = face_yaw
	pitch = face_pitch
	position = at
	rotation = Vector3(pitch, yaw, 0.0)
	active = true
	current = true


func dock() -> void:
	active = false
	current = false
	script_wish = Vector3.ZERO
	script_yaw = 0.0


# hot
func _process(delta: float) -> void:
	if not active:
		return
	var step := minf(delta, 0.1)
	var move := Input.get_vector("yaw_left", "yaw_right", "throttle_forward", "throttle_back")
	var ix := clampf(move.x + script_wish.x, -1.0, 1.0)
	var iy := script_wish.y
	if Input.is_action_pressed("lift"):
		iy += 1.0
	if Input.is_action_pressed("drop"):
		iy -= 1.0
	iy = clampf(iy, -1.0, 1.0)
	var iz := clampf(-move.y + script_wish.z, -1.0, 1.0)
	yaw += script_yaw * step
	_wish = basis.x * ix + basis.y * iy - basis.z * iz
	motion.step(_wish, step)
	position = motion.pos
	rotation = Vector3(pitch, yaw, motion.roll)
