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
var _eye_base := Vector3.ZERO
var _eye_ready := false
var _film: ShaderMaterial
var _lpf: AudioEffectLowPassFilter


func setup(ship: Node) -> void:
	_ship = ship
	process_priority = 20
	_player = AudioStreamPlayer.new()
	_player.name = "EngineRumble"
	_player.stream = make_rumble()
	_player.volume_db = -80.0
	_player.pitch_scale = 0.78
	_lpf = AudioEffectLowPassFilter.new()
	_lpf.cutoff_hz = 160.0
	AudioServer.add_bus()
	var bus := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus, "Rumble")
	AudioServer.add_bus_effect(bus, _lpf)
	_player.bus = "Rumble"
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
	var film = get_tree().get_first_node_in_group("akari_film")
	if film is CanvasItem:
		_film = (film as CanvasItem).material as ShaderMaterial


func lag_amount() -> float:
	return _feel.lag


func _apply_view() -> void:
	var sway: Vector3 = _feel.shake_offset(FlightProfile.SHAKE)
	var back: float = _feel.push * 0.06 * FlightProfile.SHAKE
	if _chase != null and _chase.current and not _chase.held:
		_chase.fov = FlightProfile.FOV + _feel.fov_extra
		_chase.h_offset = sway.y * 0.35
		_chase.v_offset = sway.x * 0.25
		_chase.rotate_object_local(Vector3.RIGHT, sway.x)
		_chase.rotate_object_local(Vector3.UP, sway.y)
		_chase.rotate_object_local(Vector3.FORWARD, sway.z)
	elif _chase != null:
		_chase.h_offset = 0.0
		_chase.v_offset = 0.0
	if _eye != null and _eye.current:
		_eye.fov = 70.0 + _feel.fov_extra
		var walker = _ship.get("_cabin").walker
		if walker.locked:
			if not _eye_ready:
				_eye_pitch = _eye.rotation.x
				_eye_base = _eye.position
				_eye_ready = true
			_eye.rotation = Vector3(_eye_pitch + sway.x * 0.85, sway.y * 0.45, sway.z * 0.7)
			_eye.position = _eye_base + Vector3(0.0, -back * 0.25, back)
	elif _eye != null:
		_eye.h_offset = 0.0
		_eye.v_offset = 0.0
	if _film != null:
		_film.set_shader_parameter("streak", _feel.weight * 0.65)


func _pulse_engines() -> void:
	var glow: float = _feel.weight
	if glow <= 0.002:
		return
	var boost: float = 1.0 + glow * 0.42
	for flame in _flames:
		var mesh := flame as MeshInstance3D
		if mesh == null:
			continue
		mesh.scale.y *= boost
		var material := mesh.material_override as StandardMaterial3D
		if material == null:
			continue
		var col: Color = material.albedo_color
		material.albedo_color = Color(col.r, col.g, col.b, col.a) * (1.0 + glow * 0.28)


func _rumble(amount: float, step: float) -> void:
	if _player == null:
		return
	var rate := 1.35 if amount > _loud else 0.95
	_loud = FlightProfile.damp(_loud, amount, rate, step)
	_player.volume_db = linear_to_db(maxf(_loud * 0.12, 0.0001))
	_player.pitch_scale = lerpf(0.74, 1.04, _loud)
	if _lpf:
		_lpf.cutoff_hz = lerpf(150.0, 780.0, _loud)


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
