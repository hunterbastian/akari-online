extends Node3D

## Cozy cabin cheated a little larger than the fuselage, drawn on its own layer
## so the chase camera never sees it. Coordinates below are the glTF model's meters;
## build() scales them into this node's space (world meters under the counter-scale).

const _Post := preload("res://scripts/data/post_profile.gd")
const _Dress := preload("res://scripts/flight/jumpship_dress.gd")
const _Walker := preload("res://scripts/flight/cabin_walker.gd")
const _CRT := preload("res://assets/shaders/crt_green.gdshader")
const _HUD := preload("res://assets/shaders/hud_glass.gdshader")
const _Plate := preload("res://scripts/ui/hud_plate.gd")
const _FONT := "res://assets/fonts/Silkscreen-Regular.ttf"
const _Detail := preload("res://scripts/flight/cabin_detail.gd")
const _Blocks := preload("res://scripts/flight/cabin_blocks.gd")

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
var _plate: Control
var _command := ""
var _cursor_on := true
var _cursor_time := 0.0
var _prompt_held := false
var _hum: AudioStreamPlayer
var _whine: AudioStreamPlayer3D
var _steps: AudioStreamPlayer
var _hum_pb: AudioStreamGeneratorPlayback
var _whine_pb: AudioStreamGeneratorPlayback
var _hum_phase := 0.0
var _whine_phase := 0.0
var _step_acc := 0.0
var _last_walk := Vector3.ZERO
var _shot_hold := false


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
	var bezel := _paint(Color(0.07, 0.074, 0.082), 0.38, 0.18)
	var door := _paint(Color(0.12, 0.125, 0.138), 0.46, 0.2)

	# Subfloor sits under the grate tiles. Ceiling stops where the canopy opens.
	_box("Floor", _v(0.0, -0.52, -1.35), _v(2.08, 0.1, 3.2), wall, false)
	_box("CeilingRear", _v(0.0, 1.58, -0.42), _v(2.08, 0.06, 1.45), wall, true)
	_box("CeilingL", _v(-0.78, 1.58, -2.05), _v(0.42, 0.06, 1.7), wall, true)
	_box("CeilingR", _v(0.78, 1.58, -2.05), _v(0.42, 0.06, 1.7), wall, true)
	_box("WallL", _v(-1.02, 0.56, -1.35), _v(0.06, 2.08, 3.2), wall, true)
	_box("WallR", _v(1.02, 0.56, -1.35), _v(0.06, 2.08, 3.2), wall, true)
	_box("WallRear", _v(0.0, 0.56, 0.24), _v(2.08, 2.08, 0.07), wall, true)
	_box("Kick", _v(0.0, -0.22, -2.72), _v(1.7, 0.42, 0.08), trim, true)

	_box("JumpSeat", _v(-0.82, -0.22, -2.02), _v(0.4, 0.22, 0.4), cloth, false)

	_box("Door", _v(0.0, 0.42, 0.18), _v(0.62, 1.15, 0.04), door, false)
	_box("DoorBar", _v(0.22, 0.48, 0.14), _v(0.16, 0.035, 0.035), trim, false)
	_glow("DoorTell", _v(-0.22, 0.95, 0.14), _v(0.035, 0.035, 0.02), Color(1.15, 0.16, 0.07))

	_glass(_v(0.0, 0.78, -2.86), Vector2(1.55, 0.78) * _scale, 0.18)
	_glass(_v(0.0, 1.32, -2.05), Vector2(1.35, 1.45) * _scale, 1.05)

	_glow("StripL", _v(-0.9, -0.38, -1.3), _v(0.025, 0.012, 2.4), Color(0.85, 0.78, 0.62))
	_glow("StripR", _v(0.9, -0.38, -1.3), _v(0.025, 0.012, 2.4), Color(0.45, 0.75, 0.95))

	var side_size := Vector2i(400, 272) if high_quality else Vector2i(320, 216)
	var prompt_size := Vector2i(480, 360) if high_quality else Vector2i(360, 270)
	_screen("Nav", _v(-0.68, 0.82, -2.2), Vector2(0.5, 0.36) * _scale, 0.32, 0.0, "nav", side_size)
	_screen("Drive", _v(0.68, 0.82, -2.2), Vector2(0.5, 0.36) * _scale, 0.32, 0.0, "drive", side_size)
	_screen("Bay", _v(0.0, 0.92, 0.1), Vector2(0.4, 0.28) * _scale, 0.0, PI, "bay", side_size)
	# Same tilt family as the readable CRTs, dropped into the window above the dash.
	_build_hud(bezel)
	# Chunky terminal on the dash. The frame is a thin bezel, not a hood.
	_build_prompt(_v(0.0, 0.4, -1.98), prompt_size)
	_Blocks.dress(self)
	_Detail.apply(self)
	_build_walker()
	_setup_audio()


func set_walking(on: bool) -> void:
	if not _high:
		return
	var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for mesh in _shadowers:
		mesh.cast_shadow = mode


func update_readouts(speed: float, throttle: float, mina_range: float, ship_name: String, hull: int, autopilot: String) -> void:
	var spd := "%03d" % int(round(speed))
	var rng := "%05d" % int(round(maxf(mina_range, 0.0)))
	var thr := "%04.2f" % clampf(throttle, 0.0, 1.0)
	# No fuel tank yet. 1.00 is a full cell until that system exists.
	if _plate and _plate.has_method("set_readout"):
		_plate.set_readout(ship_name, hull, speed, mina_range, 1.0, autopilot, "NONE")
	_set_line("nav", "NAV\nMINA\nRNG %s\nBRG FWD\nLINK" % rng)
	_set_line("drive", "DRIVE\nSPD %s\nTHR %s\nNOM" % [spd, thr])
	_set_line("bay", "BAY\nSEALED\nCORE\n312")


func snap_view(mode: String) -> void:
	if mode == "seat":
		walker.snap(seat_point, seated_eye, -0.1, 0.0)
	elif mode == "rear":
		walker.snap(_v(0.0, 0.0, -1.86), standing_eye, -0.18, PI)
	elif mode == "storage":
		walker.snap(_v(-0.05, 0.0, -1.62), _scale * 0.88, -0.32, -2.2)
	elif mode == "dash":
		walker.snap(_v(0.0, 0.0, -1.2), _scale * 0.92, -0.42, 0.0)
	else:
		walker.snap(aisle_point, standing_eye, -0.02, 0.0)


func _process(delta: float) -> void:
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
		_command = ""
	elif key.unicode >= 32 and key.unicode < 127 and _command.length() < 8:
		_command += char(key.unicode).to_upper()
	else:
		return
	get_viewport().set_input_as_handled()
	_refresh_prompt()


func _refresh_prompt() -> void:
	var cursor := "_" if _cursor_on else " "
	_set_line("terminal", ">" + _command + cursor)


func _build_hud(bezel: Material) -> void:
	# glTF meters. Seated eye is (0, 0.72, -1.22) looking along pitch -0.22.
	var pivot := Node3D.new()
	pivot.name = "HudGlass"
	pivot.position = _v(0.0, 0.74, -1.90)
	pivot.rotation.x = 0.2
	add_child(pivot)
	pivot.add_to_group("akari_hud")

	var view_size := Vector2i(640, 360) if _high else Vector2i(512, 288)
	var viewport := SubViewport.new()
	viewport.name = "HudView"
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
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(background)
	var plate = _Plate.new()
	plate.name = "Plate"
	plate.size = Vector2(view_size)
	plate.setup(_font)
	viewport.add_child(plate)
	add_child(viewport)
	_plate = plate

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "HudPlate"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.86, 0.48375) * _scale
	mesh_instance.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = _HUD
	material.render_priority = 3
	material.set_shader_parameter("screen_tex", viewport.get_texture())
	material.set_shader_parameter("glow_spread", 0.0035 if _Post.high_quality() else 0.0)
	material.set_shader_parameter("brightness", 1.55 if _high else 1.3)
	material.set_shader_parameter("fresnel_strength", 0.28 if _high else 0.14)
	material.set_shader_parameter("edge_glow", 0.5 if _high else 0.32)
	mesh_instance.material_override = material
	mesh_instance.layers = INTERIOR_LAYER
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	pivot.add_child(mesh_instance)

	var rail := MeshInstance3D.new()
	rail.name = "HudRail"
	var rail_box := BoxMesh.new()
	rail_box.size = Vector3(quad.size.x + _scale * 0.02, _scale * 0.012, _scale * 0.014)
	rail.mesh = rail_box
	rail.position = Vector3(0.0, -quad.size.y * 0.5 - _scale * 0.004, 0.0)
	rail.material_override = bezel
	rail.layers = INTERIOR_LAYER
	rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(rail)


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
	header.text = "TERM\nREADY"
	header.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(header)
	var label := Label.new()
	label.position = Vector2(28, view_size.y * 0.46)
	label.size = Vector2(view_size.x - 56, 80)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", 48 if view_size.y >= 300 else 32)
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
	pivot.add_child(mesh_instance)


func _build_walker() -> void:
	var floor_y := _scale * -0.4
	standing_eye = _scale * 1.5
	seated_eye = _scale * 1.12
	seat_point = _v(0.0, 0.0, -1.22)
	aisle_point = _v(0.0, 0.0, -0.72)
	sit_reach = _scale * 0.62
	walker = _Walker.new()
	walker.name = "Walker"
	walker.floor_y = floor_y
	walker.eye_height = standing_eye
	walker.speed = _scale * 1.45
	walker.radius = _scale * 0.24
	walker._bob_amp = _scale * 0.028
	walker.position = Vector3(aisle_point.x, floor_y, aisle_point.z)
	walker.limit_min = _v(-0.7, 0.0, -2.05)
	walker.limit_max = _v(0.38, 0.0, 0.02)
	walker.boxes = [
		_aabb(_v(0.0, 0.0, -2.28), _v(1.4, 0.2, 0.62)),
		_aabb(_v(0.0, 0.0, -1.55), _v(0.52, 0.2, 0.4)),
		_aabb(_v(0.72, 0.0, -1.42), _v(0.55, 0.3, 1.05)),
		_aabb(_v(0.72, 0.0, -0.62), _v(0.55, 0.3, 0.55)),
		_aabb(_v(0.72, 0.0, -0.15), _v(0.55, 0.3, 0.55)),
		_aabb(_v(-0.72, 0.0, -0.15), _v(0.55, 0.3, 0.55)),
		_aabb(_v(-0.55, 0.0, -0.62), _v(0.45, 0.3, 0.45)),
		_aabb(_v(-0.82, 0.0, -2.02), _v(0.45, 0.3, 0.45)),
		_aabb(_v(-1.05, 0.0, -1.35), _v(0.16, 0.2, 3.3)),
		_aabb(_v(1.05, 0.0, -1.35), _v(0.16, 0.2, 3.3)),
		_aabb(_v(0.0, 0.0, 0.22), _v(2.2, 0.2, 0.16)),
		_aabb(_v(0.0, 0.0, -2.95), _v(2.2, 0.2, 0.2)),
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
	_steps.volume_db = -10.0
	add_child(_steps)
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
		if walker:
			_last_walk = walker.position
		return
	_step_acc += walker.position.distance_to(_last_walk)
	_last_walk = walker.position
	if _step_acc > _scale * 0.52:
		_step_acc = 0.0
		_steps.pitch_scale = 0.92 + randf() * 0.16
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


func _omni(pos: Vector3, color: Color, energy: float, range: float) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range
	light.shadow_enabled = false
	light.light_specular = 0.4
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
	label.add_theme_font_size_override("font_size", 32 if view_size.y >= 250 else 24)
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
	pivot.add_child(mesh_instance)


func _set_line(kind: String, text: String) -> void:
	var label: Label = _lines.get(kind)
	if label:
		label.text = text
