extends Node3D

## Suit, airlock fade, and the float outside the bay.
## The cabin is on its own layer and larger than the hull, so the two rooms
## cannot meet. Crossing the threshold fogs the visor, then the camera is the
## real jumpship at the aft mouth. The frost hides the swap.

const _MOTION := preload("res://scripts/flight/eva_motion.gd")
const _PILOT := preload("res://scripts/flight/eva_pilot.gd")
const _VISOR := preload("res://assets/shaders/eva_visor.gdshader")
const _POST := preload("res://scripts/data/post_profile.gd")
const _PIXEL := preload("res://scripts/ui/pixel_text.gd")

const IDLE := 0
const SUITING := 1
const READY := 2
const FOG_OUT := 3
const OUT := 4
const FOG_IN := 5
const LIFTING := 6

var script_wish := Vector3.ZERO
var script_yaw := 0.0

var _ship: Node3D
var _pilot: Camera3D
var _state := IDLE
var _t := 0.0
var _visor := 0.0
var _white := 0.0
var _was_open := false
var _logged_out := false
var _suit_again := false
var _phone := false
var _breath_phase := 0.0
var _puff := 0.0
var _shown_o2 := -1
var _shown_line := -1
var _read_wait := 0.0
var _step := 0.016

var _mouth := Vector3(0.0, 0.6, 1.8)
var _outward := Vector3(0.0, 0.0, 1.0)
var _mat: ShaderMaterial
var _rect: ColorRect
var _layer: CanvasLayer
var _o2: Label
var _line: Label
var _breath: AudioStreamPlayer
var _hiss: AudioStreamPlayer
var _slats: Array[MeshInstance3D] = []
var _slat_y: PackedFloat32Array = PackedFloat32Array()
var _spot: SpotLight3D
var _omni: OmniLight3D
var _rake: SpotLight3D
var _glow: MeshInstance3D
var _motes: Array[MeshInstance3D] = []
var _vx := PackedFloat32Array()
var _vy := PackedFloat32Array()
var _vz := PackedFloat32Array()
var _mote_n := 0
var _mote_ceiling := 2.0
var _slat_lift := 0.8
var _puffs: Array[MeshInstance3D] = []
var _puff_home: Array[Vector3] = []
var _puff_rise := PackedFloat32Array()


func setup(ship: Node3D) -> void:
	_ship = ship
	_phone = _POST.quality() == "low"
	_pilot = _PILOT.new()
	add_child(_pilot)
	_find_mouth()
	_build_motes()
	_build_puff()
	_build_visor()
	_build_audio()


func owns_look() -> bool:
	return _state == OUT


func holds_ship() -> bool:
	return _state == FOG_OUT or _state == OUT or _state == FOG_IN


func add_look(relative: Vector2) -> void:
	if _pilot != null and _pilot.has_method("add_look"):
		_pilot.add_look(relative)


func _process(delta: float) -> void:
	if _ship == null:
		return
	var step := minf(delta, 0.1)
	_step = step
	var cabin = _ship.get("_cabin")
	if cabin == null or cabin.walker == null or cabin.bay_door == null:
		return
	var door = cabin.bay_door
	var open: bool = bool(door.is_open())
	var amount := 0.0
	if door.has_method("openness"):
		amount = float(door.openness())
	_dress_bay(amount)
	_drift_motes(step)
	_tick_puff(step)
	var walker = cabin.walker
	walker.rear_open = amount > 0.72 and _state != OUT and _state != FOG_IN
	if _state == IDLE and open and not _was_open and bool(_ship.get("walking")) and not walker.locked:
		_begin_suit()
	if _state == IDLE and _suit_again and open and bool(_ship.get("walking")):
		if walker.position.z > walker.exit_z - 0.16:
			_suit_again = false
			_begin_suit()
	_was_open = open
	_t += step
	_breath_phase += step
	if _state == SUITING:
		_visor = _MOTION.drop_amount(_t)
		if _visor >= 0.999:
			_visor = 1.0
			_state = READY
			_t = 0.0
	elif _state == LIFTING:
		_visor = 1.0 - _MOTION.drop_amount(_t)
		if _t >= 1.0:
			_visor = 0.0
			_state = IDLE
			_t = 0.0
			if not open:
				_suit_again = false
	elif _state == FOG_OUT:
		_run_fog(step, true)
	elif _state == FOG_IN:
		_run_fog(step, false)
	elif _state == OUT:
		_pilot.script_wish = script_wish
		_pilot.script_yaw = script_yaw
		_watch_return(open)
	if open and walker.position.z >= walker.exit_z and (_state == READY or (_state == SUITING and _visor > 0.92)):
		_begin_fog(true)
	if _state == READY and not open:
		_begin_lift()
	if _state == IDLE and open and walker.position.z < walker.exit_z - 0.3:
		_suit_again = true
	_ship.set("eva_overlay", _visor > 0.05 or _white > 0.05 or _state == OUT)
	_paint_visor()
	_paint_audio()
	if cabin.has_method("set_eva_quiet"):
		cabin.set_eva_quiet(_state == OUT or _state == FOG_IN or _state == FOG_OUT)
	if _ship.has_method("set_engines_cold"):
		_ship.set_engines_cold(_state == OUT or _state == FOG_IN or _state == FOG_OUT)


func _begin_suit() -> void:
	if _state != IDLE:
		return
	_state = SUITING
	_t = 0.0
	_visor = 0.0
	_start_puff()


func _begin_lift() -> void:
	_state = LIFTING
	_t = 0.0
	_visor = 1.0
	if _pilot:
		_pilot.dock()
	_logged_out = false


func _begin_fog(outward: bool) -> void:
	var cabin = _ship.get("_cabin")
	if cabin and cabin.walker:
		cabin.walker.active_walk = false
	_state = FOG_OUT if outward else FOG_IN
	_t = 0.0
	_white = 0.0


func _run_fog(step: float, outward: bool) -> void:
	if _t < 0.5:
		_white = clampf(_t / 0.5, 0.0, 1.0)
		return
	# The white hold is short. A 12 fps frame can step over it, so the swap
	# sticks once the glass is already opaque.
	if outward and not _logged_out:
		_launch()
	elif not outward and _logged_out:
		_recover()
	if _t < 0.56:
		_white = 1.0
		return
	var u := clampf((_t - 0.56) / 0.85, 0.0, 1.0)
	_white = 1.0 - u
	if u >= 1.0:
		_white = 0.0
		_t = 0.0
		if outward:
			_state = OUT
		else:
			_begin_lift()


func _launch() -> void:
	var at := _mouth + _outward * 1.55
	var vel := _outward * 0.7
	_pilot.launch(at, vel, _yaw_along(_outward), -0.04)
	_logged_out = true
	_show_hull(true)
	_note("mark_eva_out")
	_start_puff()


func _recover() -> void:
	_pilot.dock()
	var cabin = _ship.get("_cabin")
	if cabin and cabin.walker:
		var back: float = float(cabin.walker.exit_z) - 0.24
		cabin.walker.park_inside(Vector3(0.0, 0.0, back), 0.0)
	_show_hull(false)
	_note("mark_eva_in")
	_logged_out = false
	_suit_again = false
	_start_puff()


func _watch_return(open: bool) -> void:
	if not open or _pilot == null:
		return
	var rel: Vector3 = _pilot.position - _mouth
	var dist := rel.length()
	var along: float = rel.dot(_outward)
	var outward_speed: float = float(_pilot.motion.vel.dot(_outward))
	var closing := along < 1.25 and outward_speed < 0.05
	if dist < 1.15 and closing:
		script_wish = Vector3.ZERO
		script_yaw = 0.0
		_begin_fog(false)


func _note(method: String) -> void:
	var log = _ship.get("_log")
	if log != null and log.has_method(method):
		log.call(method)


func _yaw_along(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


func _show_hull(on: bool) -> void:
	if _ship != null and _ship.has_method("_set_shell_hidden"):
		_ship._set_shell_hidden(not on)


func _paint_visor() -> void:
	if _mat == null:
		return
	var show := _visor > 0.02 or _white > 0.02
	if _rect:
		_rect.visible = show
	if _layer:
		_layer.visible = show
	_mat.set_shader_parameter("drop", _visor)
	_mat.set_shader_parameter("whiteout", _white)
	_mat.set_shader_parameter("breath", _breath_phase)
	var fog := 0.15 + 0.4 * _visor
	if _state == FOG_OUT or _state == FOG_IN:
		fog = 0.85
	_mat.set_shader_parameter("fog", fog)
	_sync_readout()


func _sync_readout() -> void:
	var show := _visor > 0.62 and _white < 0.45
	if _o2:
		_o2.visible = show
	if _line:
		_line.visible = show
	if not show:
		return
	_read_wait -= _step
	if _read_wait > 0.0:
		return
	_read_wait = 0.2
	var o2 := 98
	if _state == OUT:
		o2 = 97 + int(floor(_breath_phase * 0.35)) % 2
	if o2 != _shown_o2 and _o2:
		_shown_o2 = o2
		_o2.text = "O2  %02d" % o2
	var dist := 0.0
	if _state == OUT and _pilot:
		dist = _pilot.motion.pos.length()
	var line := int(round(maxf(_MOTION.LIMIT - dist, 0.0)))
	if line != _shown_line and _line:
		_shown_line = line
		_line.text = "LINE %02d" % line


func _paint_audio() -> void:
	if _breath == null:
		return
	var on := _visor > 0.35 or _state == OUT
	var db := -16.0 if _state == OUT else -20.0
	if not on:
		db = -80.0
	_breath.volume_db = db
	if on and not _breath.playing:
		_breath.play()
	elif not on and _breath.playing and _visor < 0.05 and _state == IDLE:
		_breath.stop()


func _find_mouth() -> void:
	var hull := _ship.get_node_or_null("Hull") as Node3D
	if hull == null:
		return
	var fuse := hull.find_child("Fuselage", true, false) as MeshInstance3D
	if fuse == null or fuse.mesh == null:
		return
	var bounds: AABB = fuse.mesh.get_aabb()
	var cy := bounds.position.y + bounds.size.y * 0.46
	var rear := bounds.position.z + bounds.size.z
	var local := Vector3(0.0, cy, rear + 0.12)
	_mouth = _ship.to_local(fuse.to_global(local))
	var center := _ship.to_local(fuse.to_global(bounds.get_center()))
	_outward = _mouth - center
	if _outward.length() < 0.05:
		_outward = Vector3(0.0, 0.0, 1.0)
	else:
		_outward = _outward.normalized()
	_slat_lift = minf(bounds.size.y * 0.18, 0.22)
	for i in 4:
		var slat := fuse.get_node_or_null("BayMark%d" % i) as MeshInstance3D
		if slat == null:
			continue
		_slats.append(slat)
		_slat_y.append(slat.position.y)
	_build_throat(fuse, bounds, cy, rear)


func _build_throat(fuse: MeshInstance3D, bounds: AABB, cy: float, rear: float) -> void:
	var width := minf(bounds.size.x * 0.28, 1.35)
	var height := minf(bounds.size.y * 0.22, 0.9)
	var hole := MeshInstance3D.new()
	hole.name = "BayThroat"
	var box := BoxMesh.new()
	box.size = Vector3(width, height, 0.05)
	hole.mesh = box
	hole.position = Vector3(0.0, cy, rear + 0.03)
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.albedo_color = Color(0.04, 0.035, 0.03)
	hole.material_override = dark
	hole.layers = 1 << 1
	hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fuse.add_child(hole)
	_glow = MeshInstance3D.new()
	_glow.name = "BayGlow"
	var quad := QuadMesh.new()
	quad.size = Vector2(width * 0.62, height * 0.55)
	_glow.mesh = quad
	_glow.position = Vector3(0.0, cy, rear + 0.06)
	var warm := StandardMaterial3D.new()
	warm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	warm.albedo_color = Color(1.0, 0.62, 0.32)
	warm.emission_enabled = true
	warm.emission = Color(1.0, 0.55, 0.22)
	warm.emission_energy_multiplier = 3.6
	_glow.material_override = warm
	_glow.layers = 1 << 1
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fuse.add_child(_glow)
	_spot = SpotLight3D.new()
	_spot.name = "BaySpill"
	# Just outside the hatch, aimed back at the white plates.
	_spot.position = Vector3(0.0, cy, rear + 1.35)
	_spot.rotation = Vector3(0.0, 0.0, 0.0)
	_spot.light_color = Color(1.0, 0.7, 0.42)
	_spot.light_energy = 0.0
	_spot.spot_range = 14.0
	_spot.spot_angle = 54.0
	_spot.spot_attenuation = 0.6
	_spot.shadow_enabled = false
	_spot.light_cull_mask = 1 << 1
	fuse.add_child(_spot)
	_omni = OmniLight3D.new()
	_omni.name = "BayFill"
	_omni.position = Vector3(0.0, cy, rear + 0.2)
	_omni.light_color = Color(1.0, 0.64, 0.38)
	_omni.light_energy = 0.0
	_omni.omni_range = 9.0
	_omni.shadow_enabled = false
	_omni.light_cull_mask = 1 << 1
	fuse.add_child(_omni)
	# A cool rake on the rear quarter, so the white flank reads against space.
	_rake = SpotLight3D.new()
	_rake.name = "SunRake"
	_rake.position = Vector3(bounds.size.x * 0.42, cy + bounds.size.y * 0.12, rear + 1.1)
	_rake.light_color = Color(1.0, 0.96, 0.9)
	_rake.light_energy = 0.0
	_rake.spot_range = 16.0
	_rake.spot_angle = 38.0
	_rake.spot_attenuation = 0.7
	_rake.shadow_enabled = false
	_rake.light_cull_mask = 1 << 1
	fuse.add_child(_rake)
	_rake.look_at(fuse.to_global(bounds.get_center()), Vector3.UP)


func _dress_bay(amount: float) -> void:
	var lift := amount * _slat_lift
	for i in _slats.size():
		_slats[i].position.y = _slat_y[i] + lift
	for mote in _motes:
		mote.visible = amount > 0.08
	# A warm pool on the paint. The sun does the rim; these stay low so the hull
	# does not burn out into the planet.
	var spill := amount * (1.1 if _phone else 2.2)
	if _spot:
		_spot.light_energy = spill
	if _omni:
		_omni.light_energy = amount * (0.6 if _phone else 1.3)
	if _rake:
		_rake.light_energy = amount * (0.7 if _phone else 1.5)
	if _glow:
		var warm := _glow.material_override as StandardMaterial3D
		if warm:
			warm.emission_energy_multiplier = 0.12 + amount * (0.45 if _phone else 0.85)


func _build_motes() -> void:
	var hull := _ship.get_node_or_null("Hull") as Node3D
	if hull == null:
		return
	var fuse := hull.find_child("Fuselage", true, false) as MeshInstance3D
	if fuse == null or fuse.mesh == null:
		return
	var bounds: AABB = fuse.mesh.get_aabb()
	var cy := bounds.position.y + bounds.size.y * 0.46
	var rear := bounds.position.z + bounds.size.z
	_mote_ceiling = cy + 0.85
	_mote_n = _MOTION.mote_count(_phone)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.012, 0.016)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.82, 0.88, 0.95, 0.28)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var rng := RandomNumberGenerator.new()
	rng.seed = 2001
	_vx.resize(_mote_n)
	_vy.resize(_mote_n)
	_vz.resize(_mote_n)
	for i in _mote_n:
		var mote := MeshInstance3D.new()
		mote.mesh = mesh
		mote.material_override = mat
		mote.layers = 1 << 1
		mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mote.position = Vector3(rng.randf_range(-0.35, 0.35), cy + rng.randf_range(-0.25, 0.35), rear + rng.randf_range(0.05, 0.85))
		fuse.add_child(mote)
		_motes.append(mote)
		_vx[i] = rng.randf_range(-0.04, 0.04)
		_vy[i] = rng.randf_range(0.015, 0.05)
		_vz[i] = rng.randf_range(0.01, 0.04)


# hot
func _drift_motes(delta: float) -> void:
	var i := 0
	while i < _mote_n:
		var mote := _motes[i]
		var p := mote.position
		p.x += _vx[i] * delta
		p.y += _vy[i] * delta
		p.z += _vz[i] * delta
		if p.y > _mote_ceiling:
			p.y -= 0.7
		if p.x > 0.7:
			p.x = -0.5
		elif p.x < -0.7:
			p.x = 0.5
		mote.position = p
		i += 1


func _build_puff() -> void:
	var cabin = _ship.get("_cabin")
	if cabin == null:
		return
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.08, 0.1) * cabin._scale
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.75, 0.82, 0.86, 0.45)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var count := 3 if _phone else 6
	var rng := RandomNumberGenerator.new()
	rng.seed = 1968
	for i in count:
		var puff := MeshInstance3D.new()
		puff.mesh = mesh
		puff.material_override = mat
		puff.layers = cabin.INTERIOR_LAYER
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puff.visible = false
		var home: Vector3 = cabin._v(rng.randf_range(-0.35, 0.35), rng.randf_range(0.7, 1.5), 0.66)
		puff.position = home
		cabin.add_child(puff)
		_puffs.append(puff)
		_puff_home.append(home)
		_puff_rise.append(rng.randf_range(0.05, 0.22))


func _start_puff() -> void:
	_puff = 1.25
	for i in _puffs.size():
		_puffs[i].visible = true
		_puffs[i].position = _puff_home[i]
	if _hiss:
		_hiss.play()


func _tick_puff(delta: float) -> void:
	if _puff <= 0.0:
		return
	_puff = maxf(_puff - delta, 0.0)
	var u := 1.0 - _puff / 1.25
	for i in _puffs.size():
		var home: Vector3 = _puff_home[i]
		_puffs[i].position = home + Vector3(0.0, _puff_rise[i] * u, 0.28 * u)
		if _puff <= 0.0:
			_puffs[i].visible = false


func _build_visor() -> void:
	var host: Node = get_tree().current_scene
	if host == null:
		host = get_tree().root
	_layer = CanvasLayer.new()
	_layer.name = "EvaVisor"
	_layer.layer = 6
	_layer.visible = false
	host.add_child(_layer)
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = _VISOR
	_mat.set_shader_parameter("drop", 0.0)
	_mat.set_shader_parameter("fog", 0.0)
	_mat.set_shader_parameter("whiteout", 0.0)
	_mat.set_shader_parameter("breath", 0.0)
	_mat.set_shader_parameter("allow_fog", 0.0 if _phone else 1.0)
	_mat.set_shader_parameter("allow_reflect", 0.0 if _phone else 1.0)
	_rect.material = _mat
	_layer.add_child(_rect)
	var green := Color(0.62, 1.0, 0.72)
	_o2 = _PIXEL.make_label("O2  98")
	_o2.add_theme_color_override("font_color", green)
	_o2.visible = false
	_line = _PIXEL.make_label("LINE 40")
	_line.add_theme_color_override("font_color", green)
	_line.visible = false
	_layer.add_child(_o2)
	_layer.add_child(_line)
	get_viewport().size_changed.connect(_place_readout)
	_place_readout()


func _place_readout() -> void:
	if _o2 == null:
		return
	var view := get_viewport().get_visible_rect().size
	var size_px := _PIXEL.pixel_size(view.y)
	_o2.add_theme_font_size_override("font_size", size_px)
	_line.add_theme_font_size_override("font_size", size_px)
	_o2.position = Vector2(28.0, view.y - size_px * 3.2)
	_line.position = Vector2(28.0, view.y - size_px * 1.8)


func _build_audio() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_breath = AudioStreamPlayer.new()
	_breath.stream = _breath_wav()
	_breath.volume_db = -80.0
	_breath.bus = "Master"
	add_child(_breath)
	_hiss = AudioStreamPlayer.new()
	_hiss.stream = _hiss_wav()
	_hiss.volume_db = -8.0
	add_child(_hiss)


func _breath_wav() -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * 2.8)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2010
	for i in count:
		var t := float(i) / float(rate)
		var cycle := fmod(t, 2.8) / 2.8
		var env := sin(cycle * PI)
		env = env * env
		var noise := rng.randf_range(-1.0, 1.0)
		var body := sin(t * TAU * 140.0) * 0.15
		var hum := sin(t * TAU * 92.0) * 0.22
		var sample := int(clampf((noise * 0.35 + body) * env * 7000.0 + hum * 1800.0, -32000.0, 32000.0))
		data.encode_s16(i * 2, sample)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = count
	wav.data = data
	return wav


func _hiss_wav() -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * 0.7)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1969
	for i in count:
		var t := float(i) / float(rate)
		var env := exp(-t * 3.2) * (1.0 - exp(-t * 40.0))
		var sample := int(clampf(rng.randf_range(-1.0, 1.0) * env * 14000.0, -32000.0, 32000.0))
		data.encode_s16(i * 2, sample)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
