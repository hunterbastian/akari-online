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
const _Read := preload("res://scripts/flight/flight_readout.gd")
const _Edit := preload("res://scripts/flight/terminal_edit.gd")
const BOOT_A := "AKARI 01"
const BOOT_B := "AKARI 01\nCRT OK"
const BOOT_C := "AKARI 01\nCRT OK\nLINK MINA"
## Dev compare: --terminal-variant=A..E. A ledger, B cowl, C plinth, D facet, E hauler.
const TERMINAL_VARIANT := "A"

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
var _readout := "SPD 000\nALT 00000\nHDG 000\nTHR 0.00"
var _ship_name := "AKARI"
var _hull := 0
var _mina := "00000"
var _bay_state := "SEALED"
var _view_h := 360
var _edit = _Edit.new()
var _boot_left := -1.0
var _boot_stage := -1
var _reveal_len := 0
var _reveal_goal := 0
var _reveal_wait := 0.0
var _click: AudioStreamPlayer
var _enter_key: AudioStreamPlayer
var _error_key: AudioStreamPlayer
var orbit_hold := false
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
var _session_log
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

	var prompt_size := Vector2i(640, 480) if high_quality else Vector2i(480, 360)
	# One beige terminal, centered on the dash. The forward window stays open above it.
	_build_prompt(_v(0.0, 0.52, -3.26), prompt_size)
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
	var rng := "%05d" % int(round(maxf(mina_range, 0.0)))
	var name := ship_name.to_upper()
	if name.length() > 12:
		name = name.substr(0, 12)
	orbit_hold = autopilot == "ORBIT"
	_pitch_deg = pitch_deg
	_yaw_deg = yaw_deg
	_readout = _Read.block(int(round(speed)), int(round(mina_range)), yaw_deg, throttle)
	_ship_name = name
	_hull = hull
	_mina = rng
	_bay_state = "OPEN" if bay_is_open() else "SEALED"
	_refresh_header()


func terminal_wants_keys() -> bool:
	return walker != null and walker.locked and walker.eye != null and walker.eye.current


func release_fixed_view() -> void:
	# A dev teleport is a place to start walking, not a camera you cannot leave.
	if walker:
		walker.locked = false


func snap_view(mode: String) -> void:
	show_hotbar = mode != "seat" and mode != "quarter"
	if mode == "seat":
		walker.snap(seat_point, seated_eye, -0.12, 0.0)
	elif mode == "quarter":
		# Off the aisle, so the terminal's right cheek and top read together.
		walker.snap(_v(0.78, 0.0, -1.85), standing_eye, -0.38, 0.48)
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
	var on := fmod(_cursor_time, 0.9) < 0.55
	if on != _cursor_on:
		_cursor_on = on
		_refresh_prompt()
	if _boot_stage < 0 and terminal_wants_keys():
		_boot_stage = 0
		_boot_left = 1.6
		_show_boot()
	if _boot_left > 0.0:
		_boot_left -= delta
		var stage := 2
		if _boot_left > 1.1:
			stage = 0
		elif _boot_left > 0.55:
			stage = 1
		elif _boot_left <= 0.0:
			stage = 3
		if stage != _boot_stage:
			_boot_stage = stage
			_show_boot()
	elif _reveal_len < _reveal_goal:
		_reveal_wait += delta
		if _reveal_wait >= 0.012:
			_reveal_wait = 0.0
			_reveal_len += 1
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
	if _boot_left > 0.0:
		_finish_boot()
		get_viewport().set_input_as_handled()
		return
	if _reveal_len < _reveal_goal:
		_reveal_len = _reveal_goal
		_refresh_prompt()
		get_viewport().set_input_as_handled()
		return
	if key.keycode == KEY_UP:
		_edit.up()
	elif key.keycode == KEY_DOWN:
		_edit.down()
	elif key.keycode == KEY_TAB:
		_edit.complete()
		_key_sound(0)
	elif key.keycode == KEY_BACKSPACE:
		_edit.backspace()
		_key_sound(0)
	elif key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		terminal_submit()
		get_viewport().set_input_as_handled()
		return
	elif key.unicode >= 32 and key.unicode < 127:
		_edit.type_char(char(key.unicode))
		_key_sound(0)
	else:
		return
	get_viewport().set_input_as_handled()
	_refresh_prompt()


func terminal_type(ch: String) -> void:
	_finish_boot()
	_edit.type_char(ch)
	_key_sound(0)
	_refresh_prompt()


func terminal_tab() -> void:
	_finish_boot()
	_edit.complete()
	_key_sound(0)
	_refresh_prompt()


func terminal_history(step: int) -> void:
	_finish_boot()
	if step < 0:
		_edit.up()
	else:
		_edit.down()
	_refresh_prompt()


func terminal_submit_text(line: String) -> void:
	_finish_boot()
	_edit.line = line
	terminal_submit()


func set_log(log) -> void:
	_session_log = log


func lamp_preset() -> String:
	if _lamps == null:
		return ""
	return _lamps.preset


func restore_lamp_preset(name: String) -> void:
	if _lamps == null or not _lamps.set_preset(name):
		return
	_lamps.tint = _lamps.target_tint
	_lamps.gain = _lamps.target_gain
	_push_lamps()


func terminal_submit() -> void:
	var typed: String = _edit.line
	_edit.remember(typed)
	var reply: String = _Term.submit(typed, _lamps, _session_log)
	if reply.begins_with("LIGHTS ") and not reply.contains("?") and _session_log != null:
		var preset := reply.trim_prefix("LIGHTS ")
		if not preset.contains(" "):
			_session_log.note("Cabin lights " + preset.to_lower())
	var pilot = _flight_ship()
	if reply == "SHIP STATE SAVED":
		if pilot == null or not pilot.has_method("save_game") or not pilot.save_game():
			reply = "SAVE FAILED"
		elif _session_log != null:
			_session_log.blip = false
	elif pilot != null and reply == "AUTOPILOT ORBIT":
		pilot.engage_orbit()
	elif pilot != null and reply == "AUTOPILOT OFF":
		pilot.request_orbit_stop()
	if not reply.is_empty():
		_reply = reply
	_reveal_len = 0
	_reveal_goal = reply.length()
	_reveal_wait = 0.0
	if reply.begins_with("?"):
		_key_sound(2)
	else:
		_key_sound(1)
	_refresh_prompt()


func _flight_ship():
	var node: Node = get_parent()
	while node != null:
		if node.has_method("save_game") or node.has_method("engage_orbit"):
			return node
		node = node.get_parent()
	return null


func _refresh_prompt() -> void:
	if _boot_left > 0.0:
		_set_line("terminal", "")
		return
	var cursor := "█" if _cursor_on else " "
	var shown := _reply
	if _reveal_goal > 0 and _reveal_len < _reveal_goal:
		shown = _reply.substr(0, _reveal_len)
	var multi := shown.contains("\n")
	var prompt: Label = _lines.get("terminal")
	if prompt:
		prompt.position.y = _view_h * (0.78 if multi else 0.82)
	_set_line("terminal", ">" + _edit.line + cursor)
	if _term_header:
		if multi:
			_term_header.add_theme_font_size_override("font_size", 18 if _view_h >= 400 else 14)
			_term_header.size.y = _view_h * 0.74
			_term_header.text = shown
		else:
			_term_header.add_theme_font_size_override("font_size", 22 if _view_h >= 400 else 16)
			_term_header.size.y = _view_h * 0.64
			_refresh_header()
	if _term_reply:
		_term_reply.position.y = _view_h * 0.68
		if _session_log != null and _session_log.blip and shown.is_empty() and not multi:
			_term_reply.text = "NEW LOG"
		elif multi:
			_term_reply.text = ""
		else:
			_term_reply.text = shown


func show_orbit(on: bool) -> void:
	orbit_hold = on
	_refresh_header()


func _finish_boot() -> void:
	if _boot_stage >= 3 and _boot_left <= 0.0:
		return
	_boot_left = 0.0
	_boot_stage = 3
	_show_boot()


func _show_boot() -> void:
	if _term_header == null:
		return
	if _boot_stage <= 0:
		_term_header.text = BOOT_A
	elif _boot_stage == 1:
		_term_header.text = BOOT_B
	elif _boot_stage == 2:
		_term_header.text = BOOT_C
	else:
		_refresh_header()
		_refresh_prompt()


func _refresh_header() -> void:
	if _term_header == null or _boot_left > 0.0:
		return
	_term_header.text = _Read.page(_readout, orbit_hold, _ship_name, _hull, _mina, _bay_state)


func _build_prompt(pos: Vector3, view_size: Vector2i) -> void:
	_view_h = view_size.y
	var root := Node3D.new()
	root.name = "BeigeTerminal"
	add_child(root)
	root.add_to_group("akari_hud")
	var pivot := Node3D.new()
	pivot.name = "TerminalPivot"
	pivot.position = pos
	pivot.rotation.x = 0.50
	root.add_child(pivot)
	var variant := _terminal_variant()
	print("TERMINAL ", variant)
	_dress_terminal(root, pivot, variant)

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
	var status_size := 22 if view_size.y >= 400 else 16
	var header := Label.new()
	header.position = Vector2(24, 14)
	header.size = Vector2(view_size.x - 48, view_size.y * 0.64)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.autowrap_mode = TextServer.AUTOWRAP_OFF
	header.clip_text = true
	header.add_theme_font_override("font", _font)
	header.add_theme_font_size_override("font_size", status_size)
	header.add_theme_color_override("font_color", Color(0.55, 1.0, 0.62))
	header.text = _Read.page(_readout, false, _ship_name, _hull, _mina, _bay_state)
	header.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(header)
	_term_header = header
	var reply := Label.new()
	reply.name = "Reply"
	reply.position = Vector2(24, view_size.y * 0.68)
	reply.size = Vector2(view_size.x - 48, 44)
	reply.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	reply.clip_text = true
	reply.add_theme_font_override("font", _font)
	reply.add_theme_font_size_override("font_size", 20 if view_size.y >= 400 else 15)
	reply.add_theme_color_override("font_color", Color(0.55, 1.0, 0.62))
	reply.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(reply)
	_term_reply = reply
	var label := Label.new()
	label.position = Vector2(24, view_size.y * 0.82)
	label.size = Vector2(view_size.x - 48, 64)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", 24 if view_size.y >= 400 else 18)
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
	quad.size = Vector2(0.68, 0.46) * _scale
	mesh_instance.mesh = quad
	mesh_instance.position = Vector3(0.0, 0.02, 0.0) * _scale
	var material := ShaderMaterial.new()
	material.shader = _CRT
	material.set_shader_parameter("screen_tex", viewport.get_texture())
	material.set_shader_parameter("glow_spread", 0.0)
	material.set_shader_parameter("brightness", 1.4 if _high else 1.22)
	material.set_shader_parameter("curvature", 0.012)
	material.set_shader_parameter("scanline_strength", 0.12)
	mesh_instance.material_override = material
	mesh_instance.layers = INTERIOR_LAYER
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.add_to_group("akari_crt")
	pivot.add_child(mesh_instance)


static func variant_letter(raw: String) -> String:
	var letter := raw.strip_edges().to_upper()
	if letter.length() == 1 and letter >= "A" and letter <= "E":
		return letter
	return "A"


func _terminal_variant() -> String:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		var text := str(arg)
		if text.begins_with("--terminal-variant="):
			return variant_letter(text.trim_prefix("--terminal-variant="))
	return variant_letter(TERMINAL_VARIANT)


func _dress_terminal(root: Node3D, pivot: Node3D, kind: String) -> void:
	# The glass transform stays put. Only the case around it changes.
	match kind:
		"B":
			_case_b(root, pivot)
		"C":
			_case_c(root, pivot)
		"D":
			_case_d(root, pivot)
		"E":
			_case_e(root, pivot)
		_:
			_case_a(root, pivot)


func _terminal_keys(root: Node3D, deck_kind: String, deck_pos: Vector3, deck_size: Vector3, worn_key: bool) -> void:
	_case_box(root, "Deck", deck_size, deck_pos, deck_kind)
	for i in 8:
		var kx := -0.28 + float(i) * 0.08
		var key_kind := "bezel" if worn_key and i == 6 else "key"
		_case_box(root, "Key%d" % i, Vector3(0.055, 0.04, 0.055), Vector3(kx, deck_pos.y + 0.05, deck_pos.z), key_kind)
	_case_box(root, "Space", Vector3(0.28, 0.032, 0.05), Vector3(0.0, deck_pos.y + 0.045, deck_pos.z + 0.10), "key")


func _case_a(root: Node3D, pivot: Node3D) -> void:
	# Golden Age workstation. Chamfered bone, one orange band, a stencil serial.
	_case_box(root, "Chassis", Vector3(0.88, 0.30, 0.56), Vector3(0.0, 0.17, -3.40), "plastic")
	_terminal_keys(root, "plastic", Vector3(0.0, 0.22, -3.08), Vector3(0.76, 0.06, 0.24), false)
	_case_box(root, "Stripe", Vector3(0.84, 0.028, 0.03), Vector3(0.0, 0.29, -3.12), "accent")
	_case_box(root, "Stencil", Vector3(0.16, 0.045, 0.02), Vector3(-0.28, 0.24, -3.11), "stencil")
	for i in 4:
		var vx := -0.18 + float(i) * 0.12
		_case_box(root, "Vent%d" % i, Vector3(0.08, 0.025, 0.04), Vector3(vx, 0.33, -3.52), "bezel")
	_case_box(pivot, "Shell", Vector3(0.90, 0.66, 0.18), Vector3(0.0, -0.02, -0.12), "plastic")
	_case_box(pivot, "Tube", Vector3(0.74, 0.52, 0.03), Vector3(0.0, 0.02, -0.02), "bezel")
	_case_box(pivot, "BezelTop", Vector3(0.90, 0.08, 0.10), Vector3(0.0, 0.30, 0.02), "plastic")
	_case_box(pivot, "BezelChin", Vector3(0.90, 0.12, 0.12), Vector3(0.0, -0.28, 0.03), "plastic")
	_case_box(pivot, "BezelL", Vector3(0.09, 0.52, 0.10), Vector3(-0.405, 0.02, 0.02), "plastic")
	_case_box(pivot, "BezelR", Vector3(0.09, 0.52, 0.10), Vector3(0.405, 0.02, 0.02), "plastic")
	_case_box(pivot, "ChamferL", Vector3(0.07, 0.50, 0.07), Vector3(-0.44, 0.02, 0.05), "plastic", Vector3(0.0, 0.78, 0.0))
	_case_box(pivot, "ChamferR", Vector3(0.07, 0.50, 0.07), Vector3(0.44, 0.02, 0.05), "plastic", Vector3(0.0, -0.78, 0.0))
	_case_box(pivot, "ChamferBrow", Vector3(0.78, 0.055, 0.055), Vector3(0.0, 0.35, 0.06), "plastic", Vector3(0.65, 0.0, 0.0))
	_case_box(pivot, "Inset", Vector3(0.025, 0.18, 0.10), Vector3(-0.46, 0.04, -0.04), "warmgrey")
	for i in 3:
		_case_box(pivot, "SideVent%d" % i, Vector3(0.04, 0.026, 0.10), Vector3(0.46, 0.12 - float(i) * 0.08, -0.05), "bezel")
	_bolts(pivot, "Brow", [Vector3(-0.36, 0.30, 0.08), Vector3(0.36, 0.30, 0.08), Vector3(-0.36, -0.22, 0.09), Vector3(0.36, -0.22, 0.09)])
	_case_box(pivot, "Badge", Vector3(0.14, 0.04, 0.02), Vector3(0.28, 0.30, 0.09), "badge")
	_case_box(pivot, "Pip", Vector3(0.02, 0.02, 0.018), Vector3(0.34, 0.30, 0.10), "lamp")


func _case_b(root: Node3D, pivot: Node3D) -> void:
	# Jumpship cowl. A faceted hood and two struts bolted to the dash.
	_case_box(root, "Chassis", Vector3(1.02, 0.18, 0.50), Vector3(0.0, 0.12, -3.42), "plastic")
	_terminal_keys(root, "plastic", Vector3(0.0, 0.20, -3.08), Vector3(0.72, 0.05, 0.22), false)
	_case_box(root, "StrutL", Vector3(0.07, 0.58, 0.08), Vector3(-0.56, 0.40, -3.24), "steel", Vector3(0.0, 0.0, 0.28))
	_case_box(root, "StrutR", Vector3(0.07, 0.58, 0.08), Vector3(0.56, 0.40, -3.24), "steel", Vector3(0.0, 0.0, -0.28))
	_case_box(root, "FootL", Vector3(0.14, 0.03, 0.12), Vector3(-0.62, 0.20, -3.22), "steel")
	_case_box(root, "FootR", Vector3(0.14, 0.03, 0.12), Vector3(0.62, 0.20, -3.22), "steel")
	_bolts(root, "Foot", [Vector3(-0.66, 0.23, -3.18), Vector3(-0.58, 0.23, -3.26), Vector3(0.66, 0.23, -3.18), Vector3(0.58, 0.23, -3.26)])
	_case_box(pivot, "Shell", Vector3(0.86, 0.62, 0.16), Vector3(0.0, -0.02, -0.14), "plastic")
	_case_box(pivot, "Tube", Vector3(0.74, 0.52, 0.03), Vector3(0.0, 0.02, -0.02), "bezel")
	_case_box(pivot, "BezelTop", Vector3(0.78, 0.06, 0.08), Vector3(0.0, 0.28, 0.02), "warmgrey")
	_case_box(pivot, "BezelChin", Vector3(0.78, 0.08, 0.08), Vector3(0.0, -0.26, 0.02), "warmgrey")
	_case_box(pivot, "BezelL", Vector3(0.06, 0.46, 0.08), Vector3(-0.38, 0.02, 0.02), "warmgrey")
	_case_box(pivot, "BezelR", Vector3(0.06, 0.46, 0.08), Vector3(0.38, 0.02, 0.02), "warmgrey")
	_case_box(pivot, "Hood", Vector3(1.06, 0.08, 0.26), Vector3(0.0, 0.40, 0.06), "plastic", Vector3(-0.22, 0.0, 0.0))
	_case_box(pivot, "HoodLip", Vector3(1.08, 0.025, 0.03), Vector3(0.0, 0.36, 0.18), "accent")
	_bolts(pivot, "Strut", [Vector3(-0.40, 0.16, 0.06), Vector3(0.40, 0.16, 0.06)])
	_case_box(pivot, "Badge", Vector3(0.12, 0.035, 0.02), Vector3(-0.32, 0.40, 0.12), "badge")


func _case_c(root: Node3D, pivot: Node3D) -> void:
	# Tower terminal. Stepped plinth, cable loops, a hazard-striped tray.
	_case_box(root, "Plinth", Vector3(1.16, 0.10, 0.72), Vector3(0.0, 0.06, -3.36), "warmgrey")
	_case_box(root, "PlinthTop", Vector3(0.98, 0.12, 0.58), Vector3(0.0, 0.16, -3.40), "plastic")
	_terminal_keys(root, "plastic", Vector3(0.0, 0.24, -3.02), Vector3(0.82, 0.05, 0.30), false)
	_case_box(root, "TrayLip", Vector3(0.84, 0.032, 0.045), Vector3(0.0, 0.27, -2.86), "caution")
	_cable(root, "CableL", Vector3(-0.58, 0.50, -3.30))
	_cable(root, "CableR", Vector3(0.58, 0.48, -3.22))
	_case_box(pivot, "Shell", Vector3(0.98, 0.72, 0.22), Vector3(0.0, -0.02, -0.14), "plastic")
	_case_box(pivot, "Tube", Vector3(0.74, 0.52, 0.03), Vector3(0.0, 0.02, -0.02), "bezel")
	_case_box(pivot, "BezelTop", Vector3(0.98, 0.10, 0.12), Vector3(0.0, 0.32, 0.02), "warmgrey")
	_case_box(pivot, "BezelChin", Vector3(0.98, 0.14, 0.14), Vector3(0.0, -0.30, 0.03), "warmgrey")
	_case_box(pivot, "BezelL", Vector3(0.12, 0.52, 0.12), Vector3(-0.43, 0.02, 0.02), "warmgrey")
	_case_box(pivot, "BezelR", Vector3(0.12, 0.52, 0.12), Vector3(0.43, 0.02, 0.02), "warmgrey")
	_case_box(pivot, "Keeper", Vector3(0.10, 0.04, 0.02), Vector3(0.32, -0.30, 0.10), "accent")
	_bolts(pivot, "Plinth", [Vector3(-0.42, 0.32, 0.09), Vector3(0.42, 0.32, 0.09)])
	_case_box(pivot, "Badge", Vector3(0.14, 0.04, 0.02), Vector3(-0.30, 0.32, 0.09), "badge")


func _case_d(root: Node3D, pivot: Node3D) -> void:
	# Ghost shell. Faceted bone plates around the same green tube.
	_case_box(root, "Chassis", Vector3(0.84, 0.24, 0.50), Vector3(0.0, 0.14, -3.40), "plastic")
	_terminal_keys(root, "plastic", Vector3(0.0, 0.22, -3.08), Vector3(0.70, 0.05, 0.22), false)
	_case_box(pivot, "Core", Vector3(0.80, 0.58, 0.10), Vector3(0.0, 0.02, -0.06), "bezel")
	_case_box(pivot, "CrownL", Vector3(0.42, 0.07, 0.08), Vector3(-0.18, 0.34, 0.05), "plastic", Vector3(0.15, 0.0, 0.28))
	_case_box(pivot, "CrownR", Vector3(0.42, 0.07, 0.08), Vector3(0.18, 0.34, 0.05), "plastic", Vector3(0.15, 0.0, -0.28))
	_case_box(pivot, "CheekL", Vector3(0.09, 0.40, 0.14), Vector3(-0.46, 0.04, 0.06), "plastic", Vector3(0.0, 0.55, 0.0))
	_case_box(pivot, "CheekR", Vector3(0.11, 0.32, 0.14), Vector3(0.48, 0.00, 0.05), "warmgrey", Vector3(0.0, -0.62, 0.16))
	_case_box(pivot, "JawL", Vector3(0.38, 0.07, 0.08), Vector3(-0.16, -0.30, 0.05), "plastic", Vector3(-0.1, 0.0, -0.2))
	_case_box(pivot, "JawR", Vector3(0.34, 0.08, 0.08), Vector3(0.18, -0.31, 0.05), "plastic", Vector3(-0.15, 0.15, 0.16))
	_case_box(pivot, "Brow", Vector3(0.22, 0.045, 0.06), Vector3(0.0, 0.30, 0.07), "warmgrey")
	_case_box(pivot, "Tick", Vector3(0.06, 0.02, 0.02), Vector3(0.30, 0.36, 0.08), "accent")
	_case_box(pivot, "Badge", Vector3(0.10, 0.032, 0.018), Vector3(-0.28, -0.30, 0.09), "badge")


func _case_e(root: Node3D, pivot: Node3D) -> void:
	# Field rig. Scuffed bone, a handle, latches, and a short antenna.
	_case_box(root, "Chassis", Vector3(0.90, 0.28, 0.54), Vector3(0.0, 0.16, -3.40), "worn")
	_terminal_keys(root, "worn", Vector3(0.0, 0.22, -3.08), Vector3(0.76, 0.06, 0.24), true)
	_case_box(root, "Tape", Vector3(0.16, 0.02, 0.10), Vector3(-0.26, 0.26, -3.06), "caution", Vector3(0.0, 0.5, 0.0))
	_case_box(root, "Mast", Vector3(0.03, 0.32, 0.03), Vector3(-0.50, 0.52, -3.50), "steel")
	_case_box(root, "MastTip", Vector3(0.055, 0.04, 0.055), Vector3(-0.50, 0.70, -3.50), "accent")
	_case_box(pivot, "Shell", Vector3(0.90, 0.66, 0.18), Vector3(0.0, -0.02, -0.12), "worn")
	_case_box(pivot, "Tube", Vector3(0.74, 0.52, 0.03), Vector3(0.0, 0.02, -0.02), "bezel")
	_case_box(pivot, "BezelTop", Vector3(0.90, 0.08, 0.10), Vector3(0.0, 0.30, 0.02), "worn")
	_case_box(pivot, "BezelChin", Vector3(0.90, 0.12, 0.12), Vector3(0.0, -0.28, 0.03), "worn")
	_case_box(pivot, "BezelL", Vector3(0.09, 0.52, 0.10), Vector3(-0.405, 0.02, 0.02), "worn")
	_case_box(pivot, "BezelR", Vector3(0.09, 0.52, 0.10), Vector3(0.405, 0.02, 0.02), "worn")
	_case_box(pivot, "Dent", Vector3(0.18, 0.07, 0.025), Vector3(-0.18, -0.26, 0.09), "bezel")
	_case_box(pivot, "PostL", Vector3(0.04, 0.08, 0.04), Vector3(-0.22, 0.38, -0.02), "steel")
	_case_box(pivot, "PostR", Vector3(0.04, 0.08, 0.04), Vector3(0.22, 0.38, -0.02), "steel")
	_case_box(pivot, "Handle", Vector3(0.50, 0.045, 0.045), Vector3(0.0, 0.42, -0.02), "steel")
	_case_box(pivot, "LatchA", Vector3(0.035, 0.12, 0.05), Vector3(0.47, 0.10, 0.02), "steel")
	_case_box(pivot, "LatchB", Vector3(0.035, 0.12, 0.05), Vector3(0.47, -0.10, 0.02), "steel")
	_case_box(pivot, "KeeperA", Vector3(0.02, 0.03, 0.02), Vector3(0.49, 0.10, 0.05), "accent")
	_case_box(pivot, "KeeperB", Vector3(0.02, 0.03, 0.02), Vector3(0.49, -0.10, 0.05), "accent")
	_case_box(pivot, "Badge", Vector3(0.12, 0.035, 0.02), Vector3(0.26, 0.30, 0.09), "badge")


func _cable(root: Node3D, prefix: String, origin: Vector3) -> void:
	var side := 1.0 if origin.x > 0.0 else -1.0
	for i in 4:
		var sag := Vector3(side * 0.045 * float(i), -0.09 * float(i), 0.05 * float(i))
		_case_box(root, "%s%d" % [prefix, i], Vector3(0.05, 0.055, 0.10), origin + sag, "cable")


func _bolts(parent: Node3D, prefix: String, spots: Array) -> void:
	for i in spots.size():
		var spot: Vector3 = spots[i]
		_case_box(parent, "%sBolt%d" % [prefix, i], Vector3(0.028, 0.028, 0.028), spot, "steel")


func _case_box(parent: Node3D, node_name: String, size: Vector3, pos: Vector3, kind: String, rot: Vector3 = Vector3.ZERO) -> void:
	_Blocks._local_box(parent, node_name, size * _scale, pos * _scale, _Blocks.material(kind), INTERIOR_LAYER, true)
	if rot == Vector3.ZERO:
		return
	var node := parent.get_node(node_name) as MeshInstance3D
	if node:
		node.rotation = rot


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
	_click = AudioStreamPlayer.new()
	_click.stream = _blip_wav(1680.0, 500, 0.35)
	_click.volume_db = -22.0
	add_child(_click)
	_enter_key = AudioStreamPlayer.new()
	_enter_key.stream = _blip_wav(520.0, 1100, 0.45)
	_enter_key.volume_db = -18.0
	add_child(_enter_key)
	_error_key = AudioStreamPlayer.new()
	_error_key.stream = _blip_wav(180.0, 1600, 0.5)
	_error_key.volume_db = -16.0
	add_child(_error_key)
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


func _key_sound(kind: int) -> void:
	var player: AudioStreamPlayer = _click
	if kind == 1:
		player = _enter_key
	elif kind == 2:
		player = _error_key
	if player != null:
		player.play()


func _blip_wav(freq: float, count: int, amp: float) -> AudioStreamWAV:
	var rate := 22050
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / float(rate)
		var env := exp(-t * 38.0)
		var sample := sin(TAU * freq * t) * amp * env
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 14000.0))
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
	var tone := 460.0 if orbit_hold else 2400.0
	var amp := 0.01 if orbit_hold else 0.03
	_fill_tone(_whine_pb, tone, amp, _whine_phase)
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
