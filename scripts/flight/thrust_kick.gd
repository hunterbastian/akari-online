extends Node

## Applies the thrust kick to whichever camera is flying, plus a quiet engine rumble.

const _FEEL := preload("res://scripts/flight/thrust_feel.gd")

var _ship: Node
var _feel = _FEEL.new()
var _player: AudioStreamPlayer
var _chase: Camera3D
var _eye: Camera3D
var _flames: Array = []
var _bound := false
var _loud := 0.0
var _eye_pitch := 0.0
var _eye_ready := false


func setup(ship: Node) -> void:
	_ship = ship
	process_priority = 20
	_player = AudioStreamPlayer.new()
	_player.name = "EngineRumble"
	_player.stream = make_rumble()
	_player.volume_db = -80.0
	add_child(_player)
	_player.play()


func _process(delta: float) -> void:
	if _ship == null:
		return
	_bind()
	var step := minf(delta, FlightProfile.DT_CAP)
	var amount := float(_ship.get("thrust"))
	_feel.advance(amount, step)
	_apply_view()
	_pulse_engines()
	_rumble(amount, step)


func _bind() -> void:
	if _bound:
		return
	_bound = true
	var chase = _ship.get("_chase")
	if chase is Camera3D:
		_chase = chase
	var cabin = _ship.get("_cabin")
	if cabin != null and cabin.walker != null and cabin.walker.eye is Camera3D:
		_eye = cabin.walker.eye
	var flames = _ship.get("_flames")
	if flames is Array:
		_flames = flames


func _apply_view() -> void:
	var shake := _feel.shake_offset(FlightProfile.SHAKE)
	if _chase != null and _chase.current and not _chase.held:
		_chase.fov = FlightProfile.FOV + _feel.fov_extra
		_chase.h_offset = shake.x
		_chase.v_offset = shake.y
		_chase.rotate_object_local(Vector3.RIGHT, shake.y * 0.4)
		_chase.rotate_object_local(Vector3.UP, shake.x * 0.4)
	elif _chase != null:
		_chase.h_offset = 0.0
		_chase.v_offset = 0.0
	if _eye != null and _eye.current:
		_eye.fov = 70.0 + _feel.fov_extra
		_eye.h_offset = shake.x
		_eye.v_offset = shake.y
		var walker = _ship.get("_cabin").walker
		if walker.locked:
			if not _eye_ready:
				_eye_pitch = _eye.rotation.x
				_eye_ready = true
			_eye.rotation = Vector3(_eye_pitch + shake.y * 0.55, shake.x * 0.55, shake.x * 0.12)
	elif _eye != null:
		_eye.h_offset = 0.0
		_eye.v_offset = 0.0


func _pulse_engines() -> void:
	var pulse: float = _feel.kick
	if pulse <= 0.002:
		return
	var boost: float = 1.0 + pulse * 0.7
	for flame in _flames:
		var mesh := flame as MeshInstance3D
		if mesh == null:
			continue
		mesh.scale.y *= boost


func _rumble(amount: float, step: float) -> void:
	if _player == null:
		return
	var rate := 6.5 if amount > _loud else 3.0
	_loud = FlightProfile.damp(_loud, amount, rate, step)
	_player.volume_db = linear_to_db(maxf(_loud * 0.14, 0.0001))


static func make_rumble() -> AudioStreamWAV:
	var rate := 22050
	var frames := rate * 2
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var i := 0
	while i < frames:
		var t := float(i) / float(rate)
		var body := sin(TAU * 42.0 * t) * 0.5
		body += sin(TAU * 67.0 * t) * 0.28
		body += sin(TAU * 28.0 * t) * 0.22
		var wobble := 0.78 + 0.22 * sin(TAU * 2.6 * t)
		var sample := clampf(body * wobble, -1.0, 1.0) * 0.45
		bytes.encode_s16(i * 2, int(sample * 32767.0))
		i += 1
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = frames
	stream.data = bytes
	return stream
