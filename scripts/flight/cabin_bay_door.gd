extends Node

## Shuttle-bay door. Horizontal slabs retract upward in sequence.
## A cheap shimmer sits in the opening so space stays visible.

const _FIELD := preload("res://assets/shaders/bay_field.gdshader")
const _BLOCKS := preload("res://scripts/flight/cabin_blocks.gd")

const _COUNT := 5
const _BOTTOM := -0.3
const _TOP := 1.9
var _cabin
var _segs: Array[MeshInstance3D] = []
var _closed: Array[float] = []
var _open: Array[float] = []
var _field: MeshInstance3D
var _field_mat: ShaderMaterial
var _warn: Array[MeshInstance3D] = []
var _lever := Vector3.ZERO
var _handle: MeshInstance3D
var _amount := 0.0
var _from := 0.0
var _to := 0.0
var _clock := 0.0
var _moving := false
var _want_open := false
var _sound: AudioStreamPlayer


func setup(cabin) -> void:
	_cabin = cabin
	_build()
	_apply(0.0)


func is_open() -> bool:
	return _want_open and not _moving


func openness() -> float:
	return _amount


func near_lever() -> bool:
	if _cabin == null or _cabin.walker == null:
		return false
	var at: Vector3 = _cabin.walker.position
	return Vector2(at.x, at.z).distance_to(Vector2(_lever.x, _lever.z)) <= _cabin._scale * 1.6


func try_toggle() -> bool:
	if _cabin == null or _cabin.walker == null or _cabin.walker.locked:
		return false
	if not near_lever():
		return false
	toggle()
	return true


func toggle() -> void:
	_want_open = not _want_open
	_from = _amount
	_to = 1.0 if _want_open else 0.0
	_clock = 0.0
	_moving = true
	_play()


func set_pose(mode: String) -> void:
	_moving = false
	if mode == "open":
		_want_open = true
		_apply(1.0)
	elif mode == "mid":
		_want_open = true
		_apply(0.45)
	else:
		_want_open = false
		_apply(0.0)


# hot
func _process(delta: float) -> void:
	var blink := true
	if _moving:
		_clock += delta
		var u := clampf(_clock / 2.4, 0.0, 1.0)
		u = u * u * (3.0 - 2.0 * u)
		_apply(lerpf(_from, _to, u))
		if u >= 1.0:
			_moving = false
		blink = fmod(_clock, 0.28) < 0.14
	for lamp in _warn:
		var mat := lamp.material_override as StandardMaterial3D
		if mat == null:
			continue
		var lit := Color(1.35, 0.72, 0.16) if blink else Color(0.22, 0.12, 0.04)
		mat.albedo_color = lit
		mat.emission = lit
		mat.emission_energy_multiplier = 1.6 if blink else 0.25


func _apply(amount: float) -> void:
	_amount = amount
	for i in _segs.size():
		var start := float(i) / float(_COUNT) * 0.62
		var u := clampf((amount - start) / 0.4, 0.0, 1.0)
		u = u * u * (3.0 - 2.0 * u)
		var y := lerpf(_closed[i], _open[i], u)
		_segs[i].position.y = y
	if _handle:
		_handle.rotation.x = -amount * 1.15
	if _field_mat:
		_field_mat.set_shader_parameter("openness", amount)
	if _field:
		_field.visible = amount > 0.02


func _build() -> void:
	var height := (_TOP - _BOTTOM) / float(_COUNT)
	for i in _COUNT:
		var z := 0.62 + float(i) * 0.012
		var y := _BOTTOM + height * (float(i) + 0.5)
		var seg := _BLOCKS.place(_cabin, "DoorSeg%d" % i, Vector3(0.0, y, z), Vector3(1.66, height + 0.01, 0.06), "rollup", false)
		_segs.append(seg)
		_closed.append(seg.position.y)
		_open.append(_cabin._v(0.0, _TOP + 0.08 + height * 0.5, 0.0).y)
	_hazard()
	_lever_panel()
	_field_quad()
	_lamps()
	_sound_player()


func _hazard() -> void:
	_BLOCKS.place(_cabin, "BayTrimL", Vector3(-0.9, 0.8, 0.7), Vector3(0.08, 2.25, 0.05), "hazard", false)
	_BLOCKS.place(_cabin, "BayTrimR", Vector3(0.9, 0.8, 0.7), Vector3(0.08, 2.25, 0.05), "hazard", false)
	_BLOCKS.place(_cabin, "BayTrimT", Vector3(0.0, 1.94, 0.7), Vector3(1.88, 0.08, 0.05), "hazard", false)
	_BLOCKS.place(_cabin, "BayTrimB", Vector3(0.0, -0.36, 0.7), Vector3(1.88, 0.08, 0.05), "hazard", false)


func _lever_panel() -> void:
	var panel := _BLOCKS.place(_cabin, "BayLever", Vector3(1.02, 0.95, 0.52), Vector3(0.06, 0.32, 0.24), "panel", false)
	_lever = panel.position
	_handle = _BLOCKS.place(_cabin, "BayHandle", Vector3(0.98, 0.98, 0.52), Vector3(0.08, 0.1, 0.05), "bezel", false)


func _field_quad() -> void:
	_field_mat = ShaderMaterial.new()
	_field_mat.shader = _FIELD
	_field_mat.set_shader_parameter("openness", 0.0)
	_field = MeshInstance3D.new()
	_field.name = "BayField"
	var quad := QuadMesh.new()
	quad.size = Vector2(1.62, _TOP - _BOTTOM) * _cabin._scale
	_field.mesh = quad
	_field.position = _cabin._v(0.0, (_TOP + _BOTTOM) * 0.5, 0.74)
	_field.material_override = _field_mat
	_field.layers = _cabin.INTERIOR_LAYER
	_field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_field.visible = false
	_cabin.add_child(_field)


func _lamps() -> void:
	_warn.append(_bulb("BayWarnL", Vector3(-0.98, 1.7, 0.66)))
	_warn.append(_bulb("BayWarnR", Vector3(0.98, 1.7, 0.66)))


func _bulb(node_name: String, at: Vector3) -> MeshInstance3D:
	_cabin._glow(node_name, _cabin._v(at.x, at.y, at.z), _cabin._v(0.06, 0.06, 0.04), Color(0.7, 0.45, 0.12))
	return _cabin.get_node(NodePath(node_name)) as MeshInstance3D


func _sound_player() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_sound = AudioStreamPlayer.new()
	_sound.stream = _clank()
	_sound.volume_db = -8.0
	_sound.bus = "Master"
	add_child(_sound)


func _play() -> void:
	if _sound == null:
		return
	_sound.pitch_scale = 1.0 if _want_open else 0.92
	_sound.play()


func _clank() -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * 1.6)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1701
	for i in count:
		var t := float(i) / float(rate)
		var env := exp(-t * 1.4)
		var grind := sin(t * TAU * 74.0) * 0.25 + sin(t * TAU * 41.0) * 0.18
		var hits := 0.0
		for k in 4:
			var at := 0.12 + float(k) * 0.34
			var d := absf(t - at)
			if d < 0.03:
				hits += (1.0 - d / 0.03) * (0.8 if k == 3 else 0.45)
		var noise := rng.randf_range(-1.0, 1.0) * env * 0.22
		var sample := int(clampf((grind * env + hits + noise) * 9000.0, -32000.0, 32000.0))
		data.encode_s16(i * 2, sample)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
