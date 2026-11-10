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

var _bobber = preload("res://scripts/flight/cabin_bob.gd").new()
var foot_down := false
var boot_clank := false
## Extra wish from a walk demo. Zero in normal play.
var script_wish := Vector2.ZERO
## The rear wall drops while the bay is open, and the clamp follows.
var rear_open := false
var limit_z_open := 0.0
var exit_z := 100.0

const _PASSAGE := preload("res://scripts/flight/eva_motion.gd")
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
	# The hull is on its own layer. Leave it out so an open bay shows space, not the skin.
	eye.cull_mask &= ~(1 << 1)
	eye.add_to_group("cabin_eye")
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


# hot
func _process(delta: float) -> void:
	if DevConsole.blocks_gameplay():
		return
	if not active_walk or locked or eye == null:
		return
	if controls and controls.has_method("consume_look"):
		add_look(controls.consume_look())
	var input := Input.get_vector("yaw_left", "yaw_right", "throttle_forward", "throttle_back")
	if controls and controls.has_method("move_vector"):
		input += controls.move_vector()
	input += script_wish
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
	var max_z := limit_max.z
	if limit_z_open > limit_max.z and (rear_open or position.z > limit_max.z):
		max_z = limit_z_open
	position.z = clampf(position.z, limit_min.z, max_z)
	position.y = floor_y
	_apply_bob(delta, step.length())


func park_inside(at: Vector3, look_yaw: float) -> void:
	active_walk = true
	locked = false
	if eye == null:
		return
	eye.current = true
	position = Vector3(at.x, floor_y, at.z)
	rotation.y = look_yaw
	pitch = 0.05
	eye.rotation = Vector3(pitch, 0.0, 0.0)
	eye.position = Vector3(0.0, eye_height, 0.0)


func _blocked(at: Vector3) -> bool:
	for box in boxes:
		var min_x: float = float(box["min_x"])
		var max_x: float = float(box["max_x"])
		var min_z: float = float(box["min_z"])
		var max_z: float = float(box["max_z"])
		if _PASSAGE.wall_blocks(rear_open, bool(box.get("rear", false)), at.x, at.z, min_x, max_x, min_z, max_z, radius):
			return true
	return false


func _apply_bob(delta: float, moved: float) -> void:
	var off: Vector3 = _bobber.advance(moved, delta, FlightProfile.BOB)
	foot_down = _bobber.foot
	boot_clank = _bobber.clank
	if moved > 0.00005 and FlightProfile.BOB > 0.001:
		eye.position = Vector3(off.x, eye_height + off.y, 0.0)
		eye.rotation = Vector3(pitch, 0.0, off.z)
		return
	foot_down = false
	boot_clank = false
	var settle := 1.0 - exp(-8.0 * delta)
	eye.position.y = lerpf(eye.position.y, eye_height, settle)
	eye.position.x = lerpf(eye.position.x, 0.0, settle)
	eye.rotation.z = lerpf(eye.rotation.z, 0.0, settle)
