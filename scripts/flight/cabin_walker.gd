extends Node3D

## First-person body locked to the cabin floor. Motion is local, so the ship can pitch
## and drift without dumping the pilot through a wall.

var radius := 0.11
var speed := 0.75
var eye_height := 0.7
var floor_y := 0.0
var boxes: Array = []
var limit_min := Vector3(-0.4, 0.0, -1.2)
var limit_max := Vector3(0.4, 0.0, 0.05)
var active_walk := false
var locked := false
var pitch := 0.0
var eye: Camera3D
var controls: Node

var _bob := 0.0
var _bob_amp := 0.01

const LOOK_YAW := 0.0028
const LOOK_PITCH := 0.0022
const PITCH_LIMIT := 1.15


func _ready() -> void:
	eye = Camera3D.new()
	eye.name = "Eyes"
	eye.fov = 70.0
	eye.near = 0.02
	eye.far = 7000.0
	eye.current = false
	add_child(eye)
	eye.position = Vector3(0.0, eye_height, 0.0)


func set_enabled(on: bool) -> void:
	active_walk = on
	eye.current = on
	if on:
		locked = false
		pitch = 0.08
		eye.rotation.x = pitch
		rotation.y = 0.0
		position = Vector3(position.x, floor_y, position.z)


func snap(at: Vector3, height: float, look_pitch: float, yaw: float) -> void:
	locked = true
	active_walk = true
	eye.current = true
	eye_height = height
	position = Vector3(at.x, floor_y, at.z)
	rotation.y = yaw
	pitch = look_pitch
	eye.rotation = Vector3(pitch, 0.0, 0.0)
	eye.position = Vector3(0.0, eye_height, 0.0)


func add_look(relative: Vector2) -> void:
	if not active_walk or locked:
		return
	rotation.y -= relative.x * LOOK_YAW
	pitch = clampf(pitch - relative.y * LOOK_PITCH, -PITCH_LIMIT, PITCH_LIMIT)
	eye.rotation.x = pitch


func near_point(point: Vector3, distance: float) -> bool:
	return Vector2(position.x, position.z).distance_to(Vector2(point.x, point.z)) <= distance


func _process(delta: float) -> void:
	if not active_walk or locked or eye == null:
		return
	if controls and controls.has_method("consume_look"):
		add_look(controls.consume_look())
	var input := Input.get_vector("yaw_left", "yaw_right", "throttle_forward", "throttle_back")
	if controls and controls.has_method("move_vector"):
		input += controls.move_vector()
	input = input.limit_length(1.0)
	var wish := Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, rotation.y)
	var step := wish * speed * delta
	var trial := position
	trial.x += step.x
	if not _blocked(trial):
		position.x = trial.x
	trial = position
	trial.z += step.z
	if not _blocked(trial):
		position.z = trial.z
	position.x = clampf(position.x, limit_min.x, limit_max.x)
	position.z = clampf(position.z, limit_min.z, limit_max.z)
	position.y = floor_y
	_apply_bob(delta, step.length())


func _blocked(at: Vector3) -> bool:
	for box in boxes:
		var min_x: float = float(box["min_x"]) - radius
		var max_x: float = float(box["max_x"]) + radius
		var min_z: float = float(box["min_z"]) - radius
		var max_z: float = float(box["max_z"]) + radius
		if at.x > min_x and at.x < max_x and at.z > min_z and at.z < max_z:
			return true
	return false


func _apply_bob(delta: float, moved: float) -> void:
	if moved > 0.00005:
		_bob += delta * 9.0
		eye.position.y = eye_height + sin(_bob) * _bob_amp
		eye.position.x = sin(_bob * 0.5) * _bob_amp * 0.35
	else:
		_bob = 0.0
		eye.position.y = lerpf(eye.position.y, eye_height, 1.0 - exp(-8.0 * delta))
		eye.position.x = lerpf(eye.position.x, 0.0, 1.0 - exp(-8.0 * delta))
