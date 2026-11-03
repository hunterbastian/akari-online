extends Node3D

## Cozy cabin cheated a little larger than the fuselage, drawn on its own layer
## so the chase camera never sees it. Coordinates below are the glTF model's meters;
## build() scales them into this node's space (world meters under the counter-scale).

const _Post := preload("res://scripts/data/post_profile.gd")
const _Dress := preload("res://scripts/flight/jumpship_dress.gd")
const _Walker := preload("res://scripts/flight/cabin_walker.gd")
const _CRT := preload("res://assets/shaders/crt_green.gdshader")
const _FONT := "res://assets/fonts/Silkscreen-Regular.ttf"
const _Detail := preload("res://scripts/flight/cabin_detail.gd")
const _Blocks := preload("res://scripts/flight/cabin_blocks.gd")
const _Inv := preload("res://scripts/flight/cabin_inventory.gd")

const INTERIOR_LAYER := 1 << 2

var paints: Array[ShaderMaterial] = []
var walker
var seat_point := Vector3.ZERO
var aisle_point := Vector3.ZERO
var standing_eye := 0.7
var seated_eye := 0.55
var sit_reach := 0.26

var _scale := 1.0
var _high := true
var _shadowers: Array[MeshInstance3D] = []
var _lines := {}
var _font: FontFile
var _term_header: Label
var _pitch_deg := 0
var _yaw_deg := 0
var _command := ""
var _cursor_on := true
var _cursor_time := 0.0
var _prompt_held := false
var _hum: AudioStreamPlayer
var _whine: AudioStreamPlayer3D
var _steps: AudioStreamPlayer
var _clank: AudioStreamPlayer
var _hum_pb: AudioStreamGeneratorPlayback
var _whine_pb: AudioStreamGeneratorPlayback
var _hum_phase := 0.0
var _whine_phase := 0.0
var _step_acc := 0.0
var _last_walk := Vector3.ZERO
var _shot_hold := false
var inventory
var _lamps = preload("res://scripts/flight/cabin_lamps.gd").new()
const _Term := preload("res://scripts/flight/cabin_terminal.gd")
var _reply := ""
var _term_reply: Label
var _lamp_mats: Array[ShaderMaterial] = []
var _bulbs: Array[MeshInstance3D] = []
var _bulb_color: Array[Color] = []
var _spot: SpotLight3D
var _spot_energy := 0.8
var bay_door
var show_hotbar := true


func build(scale: float, high_quality: bool) -> void:
	_scale = scale
	_high = high_quality
	_font = load(_FONT)
	_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	_font.hinting = TextServer.HINTING_NONE
	_font.generate_mipmaps = false
	_font.oversampling = 1.0
	_shot_hold = OS.get_cmdline_user_args().has("--shot")
	_Blocks.prepare(_scale)
	var wall := _paint(Color(0.16, 0.165, 0.175), 0.5, 0.1)
	var trim := _paint(Color(0.2, 0.208, 0.22), 0.4, 0.12)
	var cloth := _paint(Color(0.09, 0.092, 0.105), 0.72, 0.0)
	var door := _paint(Color(0.12, 0.125, 0.138), 0.46, 0.2)

	# Bigger on the inside. The hull outside this layer does not change.
	_box("Floor", _v(0.0, -0.52, -1.7), _v(3.6, 0.1, 5.0), wall, false)
	_box("CeilingRear", _v(0.0, 2.78, -1.7), _v(3.6, 0.08, 5.0), wall, true)
	_box("CeilingL", _v(-1.35, 2.78, -3.5), _v(0.9, 0.08, 1.2), wall, true)
	_box("CeilingR", _v(1.35, 2.78, -3.5), _v(0.9, 0.08, 1.2), wall, true)
	_box("WallL", _v(-1.78, 1.12, -1.7), _v(0.08, 3.36, 5.0), wall, true)
	_box("WallR", _v(1.78, 1.12, -1.7), _v(0.08, 3.36, 5.0), wall, true)
	# Rear wall is a frame. The shuttle-bay door fills the opening.
	_box("RearL", _v(-1.32, 1.15, 0.78), _v(0.96, 3.3, 0.08), wall, true)
	_box("RearR", _v(1.32, 1.15, 0.78), _v(0.96, 3.3, 0.08), wall, true)
	_box("RearTop", _v(0.0, 2.35, 0.78), _v(1.72, 0.9, 0.08), wall, true)
	_box("Kick", _v(0.0, -0.22, -3.85), _v(2.4, 0.42, 0.08), trim, true)

	_box("JumpSeat", _v(-1.35, -0.22, -3.15), _v(0.4, 0.22, 0.4), cloth, false)

	_box("DoorBar", _v(0.0, 1.96, 0.7), _v(1.9, 0.08, 0.1), trim, false)

	_glass(_v(0.0, 1.05, -4.05), Vector2(2.4, 1.2) * _scale, 0.1)
	_glass(_v(0.0, 2.15, -3.65), Vector2(1.8, 0.42) * _scale, 0.85)

	# Practicals live in the block library. No floor-length colored strips.

	var side_size := Vector2i(400, 272) if high_quality else Vector2i(320, 216)
	var prompt_size := Vector2i(480, 360) if high_quality else Vector2i(360, 270)
	_screen("Nav", _v(-0.85, 0.95, -3.4), Vector2(0.5, 0.36) * _scale, 0.32, 0.0, "nav", side_size)
	_screen("Drive", _v(0.85, 0.95, -3.4), Vector2(0.5, 0.36) * _scale, 0.32, 0.0, "drive", side_size)
	_screen("Bay", _v(0.0, 2.05, 0.62), Vector2(0.46, 0.3) * _scale, 0.0, PI, "bay", side_size)
	# Chunky terminal on the dash. The forward window stays open.
	_build_prompt(_v(0.0, 0.42, -3.15), prompt_size)
	_Blocks.dress(self)
	_Detail.apply(self)
	_build_walker()
	inventory = _Inv.new()
	inventory.name = "Inventory"
	add_child(inventory)
	inventory.setup(self)
	bay_door = load("res://scripts/flight/cabin_bay_door.gd").new()
	bay_door.name = "BayDoor"
	add_child(bay_door)
	bay_door.setup(self)
	_setup_audio()
	_collect_lamps()


func try_bay_door() -> bool:
	return bay_door != null and bay_door.try_toggle()


func near_bay_lever() -> bool:
	return bay_door != null and bay_door.near_lever()


func bay_is_open() -> bool:
	return bay_door != null and bay_door.is_open()


func set_bay_pose(mode: String) -> void:
	if bay_door:
		bay_door.set_pose(mode)


func pulse_bay() -> void:
	if bay_door:
		bay_door.toggle()


func set_walking(on: bool) -> void:
	if not _high:
		return
	var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for mesh in _shadowers:
		mesh.cast_shadow = mode


func update_readouts(speed: float, throttle: float, mina_range: float, ship_name: String, hull: int, autopilot: String, pitch_deg: int, yaw_deg: int) -> void:
	var spd := "%03d" % int(round(speed))
	var rng := "%05d" % int(round(maxf(mina_range, 0.0)))
	var thr := "%04.2f" % clampf(throttle, 0.0, 1.0)
	var name := ship_name.to_upper()
	if name.length() > 12:
		name = name.substr(0, 12)
	var auto := "HOLD" if autopilot == "HOLD" else "STBY"
	_pitch_deg = pitch_deg
	_yaw_deg = yaw_deg
	# No fuel tank yet. 1.00 is a full cell until that system exists.
	_set_line("nav", "NAV\n%s\nHULL %d\nMINA %s\nBRG FWD" % [name, hull, rng])
	_set_line("drive", "DRIVE\nSPD %s\nFUEL 1.00\nTHR %s\nAP %s" % [spd, thr, auto])
	var bay_state := "OPEN" if bay_is_open() else "SEALED"
	_set_line("bay", "BAY\n%s\nCORE\n312" % bay_state)
	_refresh_header()


func terminal_wants_keys() -> bool:
	return walker != null and walker.locked and walker.eye != null and walker.eye.current


func release_fixed_view() -> void:
	# A dev teleport is a place to start walking, not a camera you cannot leave.
	if walker:
		walker.locked = false


func snap_view(mode: String) -> void:
	show_hotbar = mode != "seat"
	if mode == "seat":
		walker.snap(seat_point, seated_eye, -0.12, 0.0)
	elif mode == "wide":
		walker.snap(_v(0.0, 0.0, 0.05), standing_eye, -0.16, 0.0)
	elif mode == "locker" or mode == "storage":
		walker.snap(_v(0.15, 0.0, -0.55), standing_eye, -0.22, 1.35)
	elif mode == "living":
		walker.snap(_v(0.15, 0.0, -1.85), standing_eye, -0.45, -1.2)
	elif mode == "bench":
		walker.snap(_v(-0.15, 0.0, -1.7), standing_eye, -0.35, 0.8)
	elif mode == "rear":
		walker.snap(_v(0.0, 0.0, -1.4), standing_eye, -0.12, PI)
	elif mode == "crates":
		walker.snap(_v(0.05, 0.0, -1.45), _scale * 1.35, -1.05, -2.45)
	elif mode == "dash":
		walker.snap(_v(0.0, 0.0, -1.2), _scale * 0.92, -0.42, 0.0)
	elif mode == "floor":
		walker.snap(_v(0.2, 0.0, -0.5), _scale * 1.05, -0.72, 1.05)
	else:
		walker.snap(aisle_point, standing_eye, -0.02, 0.0)


# hot
func _process(delta: float) -> void:
	if _lamps != null:
		_lamps.advance(delta)
		_push_lamps()
	if not _lines.has("terminal"):
		return
	# Shots must show the cursor. A long first frame would otherwise land in the off half.
	if _shot_hold or not OS.get_environment("AKARI_CABIN").is_empty():
		if not _prompt_held:
			_cursor_on = true
			_prompt_held = true
			_refresh_prompt()
		return
	_cursor_time += delta
	var on := fmod(_cursor_time, 1.05) < 0.62
	if on != _cursor_on:
		_cursor_on = on
		_refresh_prompt()
	_ambience(delta)


func _unhandled_input(event: InputEvent) -> void:
	# Typing only while the body is locked in the seat, so WASD still walks the aisle.
	if DevConsole.blocks_gameplay():
		return
	if walker == null or not walker.locked or walker.eye == null or not walker.eye.current:
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	if key.keycode == KEY_BACKSPACE:
		_command = _command.substr(0, maxi(_command.length() - 1, 0))
	elif key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		terminal_submit()
		get_viewport().set_input_as_handled()
		return
	elif key.unicode >= 32 and key.unicode < 127 and _command.length() < 24:
		_command += char(key.unicode).to_upper()
	else:
		return
	get_viewport().set_input_as_handled()
	_refresh_prompt()


func terminal_type(ch: String) -> void:
	if _command.length() >= 24:
		return
	_command += ch.to_upper()
	_refresh_prompt()


func terminal_submit_text(line: String) -> void:
	_command = line
	terminal_submit()


func terminal_submit() -> void:
	var reply: String = _Term.submit(_command, _lamps)
	_command = ""
	if not reply.is_empty():
		_reply = reply
	_refresh_prompt()


func _refresh_prompt() -> void:
	var cursor := "_" if _cursor_on else " "
	_refresh_header()
	_set_line("terminal", ">" + _command + cursor)
	if _term_reply:
		_term_reply.text = _reply


func _refresh_header() -> void:
	if _term_header == null:
		return
	_term_header.text = "ROUTE NONE\nPIT %+03d\nYAW %03d" % [_pitch_deg, _yaw_deg]


func _build_prompt(pos: Vector3, view_size: Vector2i) -> void:
	var size := Vector2(0.52, 0.39) * _scale
	var pivot := Node3D.new()
	pivot.name = "TerminalPivot"
	pivot.position = pos
	pivot.rotation.x = 0.48
	add_child(pivot)
	pivot.add_to_group("akari_hud")

	var border := _scale * 0.055
	var depth := _scale * 0.026
	_Blocks.monitor_frame(pivot, size, border, depth, INTERIOR_LAYER)

	var viewport := SubViewport.new()
	viewport.name = "TerminalView"
	viewport.size = view_size
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.handle_input_locally = false
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	var background := ColorRect.new()
	background.color = Color(0, 0, 0, 1)
	background.size = Vector2(view_size)
	viewport.add_child(background)
	var header := Label.new()
	header.position = Vector2(28, 20)
	header.size = Vector2(view_size.x - 48, 120)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.add_theme_font_override("font", _font)
	header.add_theme_font_size_override("font_size", 32 if view_size.y >= 300 else 24)
	header.add_theme_color_override("font_color", Color(0.55, 1.0, 0.62))
	header.text = "ROUTE NONE\nPIT +00\nYAW 000"
	header.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(header)
	_term_header = header
	var reply := Label.new()
	reply.name = "Reply"
	reply.position = Vector2(28, 146)
	reply.size = Vector2(view_size.x - 48, 40)
	reply.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	reply.add_theme_font_override("font", _font)
	reply.add_theme_font_size_override("font_size", 28 if view_size.y >= 300 else 20)
	reply.add_theme_color_override("font_color", Color(0.55, 1.0, 0.62))
	reply.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(reply)
	_term_reply = reply
	var label := Label.new()
	label.position = Vector2(28, view_size.y * 0.58)
	label.size = Vector2(view_size.x - 48, 64)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", 28 if view_size.y >= 300 else 22)
	label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.62))
	label.text = ">_"
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	label.clip_text = true
	viewport.add_child(label)
	add_child(viewport)
	_lines["terminal"] = label

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Terminal"
	var quad := QuadMesh.new()
	quad.size = size
	mesh_instance.mesh = quad
	mesh_instance.position = Vector3(0.0, 0.0, depth * 0.95)
	var material := ShaderMaterial.new()
	material.shader = _CRT
	material.set_shader_parameter("screen_tex", viewport.get_texture())
	material.set_shader_parameter("glow_spread", 0.004 if _Post.high_quality() else 0.0)
	material.set_shader_parameter("brightness", 1.45 if _high else 1.25)
	material.set_shader_parameter("curvature", 0.006)
	mesh_instance.material_override = material
	mesh_instance.layers = INTERIOR_LAYER
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.add_to_group("akari_crt")
	pivot.add_child(mesh_instance)


func _build_walker() -> void:
	var floor_y := _scale * -0.4
	standing_eye = _scale * 1.5
	seated_eye = _scale * 1.12
	seat_point = _v(0.0, 0.0, -2.35)
	aisle_point = _v(0.0, 0.0, -1.6)
	sit_reach = _scale * 0.62
	walker = _Walker.new()
	walker.name = "Walker"
	walker.floor_y = floor_y
	walker.eye_height = standing_eye
	walker.speed = _scale * 1.45
	walker.radius = _scale * 0.24
	walker.speed = 0.85
	walker.position = Vector3(aisle_point.x, floor_y, aisle_point.z)
	walker.limit_min = _v(-1.15, 0.0, -3.45)
	walker.limit_max = _v(1.05, 0.0, 0.25)
	walker.boxes = [
		_aabb(_v(0.0, 0.0, -3.43), _v(2.2, 0.2, 0.7)),
		_aabb(_v(0.0, 0.0, -2.67), _v(0.55, 0.2, 0.5)),
		_aabb(_v(1.28, 0.0, -1.85), _v(0.75, 0.3, 1.15)),
		_aabb(_v(-1.4, 0.0, -0.55), _v(0.8, 0.3, 0.85)),
		_aabb(_v(-1.4, 0.0, -1.3), _v(0.8, 0.3, 0.85)),
		_aabb(_v(-1.28, 0.0, -2.25), _v(0.75, 0.3, 0.7)),
		_aabb(_v(-1.35, 0.0, -3.15), _v(0.5, 0.3, 0.5)),
		_aabb(_v(-1.82, 0.0, -1.7), _v(0.2, 0.2, 5.1)),
		_aabb(_v(1.82, 0.0, -1.7), _v(0.2, 0.2, 5.1)),
		_aabb(_v(0.0, 0.0, 0.78), _v(3.7, 0.2, 0.2)),
		_aabb(_v(0.0, 0.0, -4.1), _v(3.7, 0.2, 0.2)),
	]
	add_child(walker)


func _aabb(center: Vector3, size: Vector3) -> Dictionary:
	var half := size * 0.5
	return {
		"min_x": center.x - half.x,
		"max_x": center.x + half.x,
		"min_z": center.z - half.z,
		"max_z": center.z + half.z,
	}


func _v(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, y, z) * _scale


func _paint(color: Color, roughness: float, metallic: float) -> ShaderMaterial:
	var material := _Dress.paint_material(color, roughness, metallic, _high, color.r * 3.0)
	if _high:
		material.set_shader_parameter("clearcoat_amount", 0.04)
		material.set_shader_parameter("clearcoat_gloss", 0.4)
	paints.append(material)
	return material


func _box(node_name: String, pos: Vector3, size: Vector3, material: Material, shadows: bool) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.position = pos
	mesh_instance.material_override = material
	mesh_instance.layers = INTERIOR_LAYER
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)
	if shadows:
		_shadowers.append(mesh_instance)
	return mesh_instance


func _cyl(node_name: String, pos: Vector3, radius: float, height: float, rot: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius * _scale
	cyl.bottom_radius = radius * _scale
	cyl.height = height * _scale
	cyl.radial_segments = 6
	cyl.rings = 1
	mesh_instance.mesh = cyl
	mesh_instance.position = pos
	mesh_instance.rotation = rot
	mesh_instance.material_override = material
	mesh_instance.layers = INTERIOR_LAYER
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)
	return mesh_instance


func _sphere(node_name: String, pos: Vector3, radius: float, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var sphere := SphereMesh.new()
	sphere.radius = radius * _scale
	sphere.height = radius * _scale * 2.0
	sphere.radial_segments = 8
	sphere.rings = 6
	mesh_instance.mesh = sphere
	mesh_instance.position = pos
	mesh_instance.material_override = material
	mesh_instance.layers = INTERIOR_LAYER
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)


func _setup_audio() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_hum = AudioStreamPlayer.new()
	_attach_tone(_hum)
	_hum.volume_db = -26.0
	_whine = AudioStreamPlayer3D.new()
	_attach_tone(_whine)
	_whine.position = _v(0.0, 0.35, -2.0)
	_whine.unit_size = 0.35
	_whine.max_distance = 1.6
	_whine.volume_db = -24.0
	_steps = AudioStreamPlayer.new()
	_steps.stream = _step_wav()
	_steps.volume_db = -16.0
	add_child(_steps)
	_clank = AudioStreamPlayer.new()
	_clank.stream = _clank_wav()
	_clank.volume_db = -14.0
	add_child(_clank)
	_hum.play()
	_whine.play()
	_hum_pb = _hum.get_stream_playback() as AudioStreamGeneratorPlayback
	_whine_pb = _whine.get_stream_playback() as AudioStreamGeneratorPlayback


func _attach_tone(player) -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050
	gen.buffer_length = 0.15
	player.stream = gen
	add_child(player)


func _clank_wav() -> AudioStreamWAV:
	var rate := 22050
	var count := 3600
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / float(rate)
		var env := exp(-t * 14.0)
		var sample := sin(TAU * 210.0 * t) * 0.55
		sample += sin(TAU * 640.0 * t) * 0.2 * exp(-t * 28.0)
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * env * 9000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


func _step_wav() -> AudioStreamWAV:
	var rate := 22050
	var count := 1400
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1408
	for i in count:
		var env := 1.0 - float(i) / float(count)
		var sample := int(rng.randf_range(-1.0, 1.0) * env * env * 7000.0)
		data.encode_s16(i * 2, sample)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


func _ambience(delta: float) -> void:
	_fill_tone(_hum_pb, 78.0, 0.05, _hum_phase)
	_hum_phase += delta
	_fill_tone(_whine_pb, 2400.0, 0.03, _whine_phase)
	_whine_phase += delta
	if walker == null or not walker.active_walk or walker.locked or _steps == null:
		return
	if not walker.foot_down:
		return
	if walker.boot_clank and _clank != null:
		_clank.play()
		return
	_steps.pitch_scale = 0.94 if walker._bobber.steps % 2 == 0 else 1.05
	_steps.play()


func _fill_tone(playback: AudioStreamGeneratorPlayback, freq: float, amp: float, phase: float) -> void:
	if playback == null:
		return
	var frames := playback.get_frames_available()
	var step := TAU * freq / 22050.0
	var t := phase * freq
	for _i in frames:
		var sample := sin(t) * amp
		t += step
		playback.push_frame(Vector2(sample, sample))


func _glow(node_name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	if size.x < 0.08 and absf(size.x - size.y) < 0.001:
		var sphere := SphereMesh.new()
		sphere.radius = size.x
		sphere.height = size.x * 2.0
		sphere.radial_segments = 8
		sphere.rings = 4
		mesh_instance.mesh = sphere
	else:
		var box := BoxMesh.new()
		box.size = size
		mesh_instance.mesh = box
	mesh_instance.position = pos
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.0
	mesh_instance.material_override = material
	mesh_instance.layers = INTERIOR_LAYER
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)


func _glass(pos: Vector3, size: Vector2, tilt: float) -> void:
	var mesh_instance := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	mesh_instance.mesh = quad
	mesh_instance.position = pos
	mesh_instance.rotation.x = tilt
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.05, 0.12, 0.14, 0.16)
	material.metallic = 0.55
	material.roughness = 0.06
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if _high:
		material.clearcoat_enabled = true
		material.clearcoat = 0.8
		material.clearcoat_roughness = 0.04
	mesh_instance.material_override = material
	mesh_instance.layers = INTERIOR_LAYER
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)


func _omni(pos: Vector3, color: Color, energy: float, range_m: float, attenuation: float = 2.0) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_m
	light.omni_attenuation = attenuation
	light.shadow_enabled = false
	light.light_specular = 0.15
	add_child(light)


func _screen(node_name: String, pos: Vector3, size: Vector2, tilt: float, yaw: float, kind: String, view_size: Vector2i) -> void:
	var pivot := Node3D.new()
	pivot.name = node_name + "Pivot"
	pivot.position = pos
	pivot.rotation = Vector3(tilt, yaw, 0.0)
	add_child(pivot)
	var border := _scale * 0.05
	var depth := _scale * 0.03
	_Blocks.monitor_frame(pivot, size, border, depth, INTERIOR_LAYER)

	var viewport := SubViewport.new()
	viewport.name = node_name + "View"
	viewport.size = view_size
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.handle_input_locally = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.gui_disable_input = true
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	var background := ColorRect.new()
	background.color = Color(0, 0, 0, 1)
	background.size = Vector2(view_size)
	viewport.add_child(background)
	var label := Label.new()
	label.position = Vector2(16, 12)
	label.size = Vector2(view_size) - Vector2(28, 20)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", 24 if view_size.y >= 250 else 16)
	label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.62))
	label.text = "AKARI"
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(label)
	add_child(viewport)
	_lines[kind] = label

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var quad := QuadMesh.new()
	quad.size = size
	mesh_instance.mesh = quad
	mesh_instance.position = Vector3(0.0, 0.0, depth * 0.95)
	var material := ShaderMaterial.new()
	material.shader = _CRT
	material.set_shader_parameter("screen_tex", viewport.get_texture())
	material.set_shader_parameter("glow_spread", 0.004 if _Post.high_quality() else 0.0)
	material.set_shader_parameter("brightness", 1.4 if _high else 1.2)
	material.set_shader_parameter("curvature", 0.006)
	mesh_instance.material_override = material
	mesh_instance.layers = INTERIOR_LAYER
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.add_to_group("akari_crt")
	pivot.add_child(mesh_instance)


func _collect_lamps() -> void:
	for mat in paints:
		_lamp_mats.append(mat)
	for kind in _Blocks._mats.keys():
		var mat: ShaderMaterial = _Blocks._mats[kind]
		_lamp_mats.append(mat)
	for child in get_children():
		if not str(child.name).begins_with("Bulb") or not (child is MeshInstance3D):
			continue
		var mesh := child as MeshInstance3D
		var material := mesh.material_override as StandardMaterial3D
		if material == null:
			continue
		_bulbs.append(mesh)
		_bulb_color.append(material.emission)
	var spot := get_node_or_null("CeilShadow") as SpotLight3D
	if spot:
		_spot = spot
		_spot_energy = spot.light_energy


func _push_lamps() -> void:
	var shown: float = _lamps.shown_gain()
	var tint: Color = _lamps.tint
	var rgb := Vector3(tint.r, tint.g, tint.b)
	for mat in _lamp_mats:
		mat.set_shader_parameter("lamp_tint", rgb)
		mat.set_shader_parameter("lamp_gain", shown)
	for i in _bulbs.size():
		var material := _bulbs[i].material_override as StandardMaterial3D
		if material == null:
			continue
		var col: Color = _bulb_color[i] * tint * shown
		material.emission = col
		material.albedo_color = col
	if _spot:
		_spot.light_energy = _spot_energy * shown
		_spot.light_color = tint


func _set_line(kind: String, text: String) -> void:
	var label: Label = _lines.get(kind)
	if label:
		label.text = text
