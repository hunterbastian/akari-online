extends Node

## Debug console. On in editor, debug exports, TestFlight (`testflight` or `dev`
## custom feature), and when AKARI_DEV=1. Release exports without those stay inert.

const _PIXEL := preload("res://scripts/ui/pixel_text.gd")
const _POST := preload("res://scripts/data/post_profile.gd")
const _FONT := "res://assets/fonts/Silkscreen-Regular.ttf"
const _DITHER := preload("res://assets/shaders/console_dither.gdshader")

const GREEN := Color(0.62, 1.0, 0.72)
const DIM := Color(0.45, 0.78, 0.52)
const WARN := Color(0.86, 1.0, 0.45)
const ERR := Color(1.0, 0.62, 0.48)
const MAX_LINES := 300

var open := false

var _enabled := false
var _commands := {}
var _history: Array[String] = []
var _hist_i := -1
var _draft := ""
var _lines: Array[String] = []
var _layer: CanvasLayer
var _log: RichTextLabel
var _line: LineEdit
var _fps_label: Label
var _toast: Label
var _toast_time := 0.0
var _fps_on := false
var _fps_tick := 0.0
var _hud_on := true
var _freecam_on := false
var _freecam: Camera3D
var _freecam_yaw := 0.0
var _freecam_pitch := 0.0
var _capturing := false
var _touch_times: Array[float] = []
var _logger: Logger


func _ready() -> void:
	_enabled = _debug_on()
	if not _enabled:
		return
	_build_ui()
	_register_builtins()
	_logger = LogSink.new()
	_logger.host = self
	OS.add_logger(_logger)
	_echo("AKARI DEV  ` toggles  tab completes  up/down history")


func enabled() -> bool:
	return _enabled


func blocks_gameplay() -> bool:
	return _enabled and (open or _freecam_on)


func freecam_active() -> bool:
	return _enabled and _freecam_on


func register_command(command_name: String, callback: Callable, help_text: String) -> void:
	if not _enabled:
		return
	_commands[command_name] = {"call": callback, "help": help_text}


func present() -> void:
	if not _enabled:
		return
	_lines.clear()
	if _log:
		_log.clear()
	_echo("AKARI DEV")
	_dispatch("help")
	if not open:
		_set_open(true)


func mirror_message(message: String, is_error: bool) -> void:
	var kind := "err" if is_error else "info"
	_push_line(message.strip_edges(), kind)


func mirror_error(rationale: String, code: String, error_type: int) -> void:
	var kind := "warn" if error_type == Logger.ERROR_TYPE_WARNING else "err"
	var text := rationale if not rationale.is_empty() else code
	if text.is_empty():
		return
	_push_line(text.strip_edges(), kind)


func capture_screenshot(scale: float, clean: bool, path: String = "") -> void:
	if _capturing:
		_echo("screenshot already running")
		return
	_capturing = true
	var amount := clampf(scale, 1.0, 4.0)
	var hidden_console := false
	var root := get_tree().root
	var old_size := root.size
	if clean:
		_apply_hud(false)
		if open:
			_layer.visible = false
			hidden_console = true
		if _fps_label:
			_fps_label.visible = false
		if _toast:
			_toast.visible = false
	if amount > 1.01:
		_POST.capture_boost = amount
		_reapply_scale()
		root.size = Vector2i(maxi(1, int(round(float(old_size.x) * amount))), maxi(1, int(round(float(old_size.y) * amount))))
	for _i in 3:
		await get_tree().process_frame
	# Headless has no renderer frame to wait on; this signal never arrives there.
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	var image: Image = null
	if DisplayServer.get_name() != "headless":
		var tex := root.get_texture()
		if tex != null:
			image = tex.get_image()
	if amount > 1.01:
		root.size = old_size
		_POST.capture_boost = 1.0
		_reapply_scale()
	if clean:
		_apply_hud(_hud_on)
		if hidden_console:
			_layer.visible = open
		if _fps_label:
			_fps_label.visible = _fps_on and _hud_on
	_capturing = false
	if image == null:
		print("screenshot skipped: no framebuffer")
		return
	var saved := path
	if saved.is_empty():
		saved = _timestamp_path()
	var dir_err := _ensure_parent(saved)
	if dir_err != OK and not saved.begins_with("user://"):
		push_error("screenshot folder failed: %s" % error_string(dir_err))
	var err := image.save_png(saved)
	if err != OK:
		push_error("screenshot save failed: %s" % error_string(err))
		return
	var full := saved
	if saved.begins_with("user://"):
		full = ProjectSettings.globalize_path(saved)
	print("screenshot ", full)
	_show_toast("SAVED")


func _debug_on() -> bool:
	if OS.is_debug_build():
		return true
	if OS.has_feature("dev") or OS.has_feature("testflight"):
		return true
	return OS.get_environment("AKARI_DEV") == "1"


func _register_builtins() -> void:
	register_command("help", _cmd_help, "List commands, or help <command>")
	register_command("clear", _cmd_clear, "Clear the scrollback")
	register_command("fps", _cmd_fps, "Toggle the FPS, draw-call and memory overlay")
	register_command("tp", _cmd_tp, "tp <planet|moon|ship|cabin|aisle> or tp x y z")
	register_command("speed", _cmd_speed, "speed <mult>  flight speed multiplier")
	register_command("timescale", _cmd_timescale, "timescale <x>  Engine.time_scale")
	register_command("noclip", _cmd_freecam, "Toggle the free camera (WASD, mouse, shift)")
	register_command("freecam", _cmd_freecam, "Toggle the free camera (WASD, mouse, shift)")
	register_command("god", _cmd_god, "Toggle planet and star collision")
	register_command("quality", _cmd_quality, "quality <low|med|high>  reloads the scene")
	register_command("renderscale", _cmd_scale, "renderscale <0.3-1.0>")
	register_command("dither", _cmd_dither, "dither on|off")
	register_command("hud", _cmd_hud, "hud on|off")
	register_command("seed", _cmd_seed, "seed  prints the system seed; seed <n> regenerates")
	register_command("reload", _cmd_reload, "Reload the current scene")
	register_command("screenshot", _cmd_shot, "screenshot [scale]  PNG in user://screenshots")
	register_command("quit", _cmd_quit, "Quit the game")


func _build_ui() -> void:
	var font := load(_FONT) as FontFile
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.generate_mipmaps = false
	font.oversampling = 1.0

	_layer = CanvasLayer.new()
	_layer.name = "DevConsole"
	_layer.layer = 40
	_layer.visible = false
	add_child(_layer)

	var panel := Control.new()
	panel.name = "Panel"
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 0.333
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(panel)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.color = Color(0.01, 0.045, 0.02, 0.9)
	var dither := ShaderMaterial.new()
	dither.shader = _DITHER
	bg.material = dither
	panel.add_child(bg)

	var rule := ColorRect.new()
	rule.anchor_left = 0.0
	rule.anchor_right = 1.0
	rule.anchor_top = 1.0
	rule.anchor_bottom = 1.0
	rule.offset_top = -2.0
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.color = Color(0.45, 0.9, 0.55, 0.9)
	panel.add_child(rule)

	_log = RichTextLabel.new()
	_log.anchor_left = 0.0
	_log.anchor_top = 0.0
	_log.anchor_right = 1.0
	_log.anchor_bottom = 1.0
	_log.offset_left = 12.0
	_log.offset_top = 8.0
	_log.offset_right = -12.0
	_log.offset_bottom = -36.0
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.selection_enabled = true
	_log.mouse_filter = Control.MOUSE_FILTER_STOP
	_log.add_theme_font_override("normal_font", font)
	_log.add_theme_font_size_override("normal_font_size", 16)
	_log.add_theme_color_override("default_color", GREEN)
	_log.scroll_active = true
	panel.add_child(_log)

	_line = LineEdit.new()
	_line.anchor_left = 0.0
	_line.anchor_right = 1.0
	_line.anchor_top = 1.0
	_line.anchor_bottom = 1.0
	_line.offset_left = 12.0
	_line.offset_right = -12.0
	_line.offset_top = -32.0
	_line.offset_bottom = -6.0
	_line.placeholder_text = ">_"
	_line.add_theme_font_override("font", font)
	_line.add_theme_font_size_override("font_size", 16)
	_line.add_theme_color_override("font_color", GREEN)
	_line.add_theme_color_override("font_placeholder_color", DIM)
	_line.add_theme_color_override("caret_color", GREEN)
	var empty := StyleBoxEmpty.new()
	_line.add_theme_stylebox_override("normal", empty)
	_line.add_theme_stylebox_override("focus", empty)
	_line.text_submitted.connect(_on_submit)
	panel.add_child(_line)

	_fps_label = Label.new()
	_fps_label.name = "Fps"
	_fps_label.visible = false
	_fps_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fps_label.add_theme_font_override("font", font)
	_fps_label.add_theme_font_size_override("font_size", 16)
	_fps_label.add_theme_color_override("font_color", GREEN)
	var fps_layer := CanvasLayer.new()
	fps_layer.layer = 41
	fps_layer.add_child(_fps_label)
	add_child(fps_layer)
	_place_fps()
	get_viewport().size_changed.connect(_place_fps)

	_toast = Label.new()
	_toast.text = "SAVED"
	_toast.visible = false
	_toast.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_override("font", _PIXEL.font())
	_toast.add_theme_font_size_override("font_size", 32)
	_toast.add_theme_color_override("font_color", GREEN)
	var toast_layer := CanvasLayer.new()
	toast_layer.layer = 42
	toast_layer.add_child(_toast)
	add_child(toast_layer)
	_place_toast()


func _place_fps() -> void:
	if _fps_label == null:
		return
	var view := get_viewport().get_visible_rect().size
	_fps_label.position = Vector2(view.x - 220.0, 12.0)
	_fps_label.size = Vector2(208.0, 64.0)


func _place_toast() -> void:
	if _toast == null:
		return
	var view := get_viewport().get_visible_rect().size
	_toast.position = Vector2((view.x - 180.0) * 0.5, view.y * 0.42)
	_toast.size = Vector2(180.0, 40.0)


func _process(delta: float) -> void:
	if not _enabled:
		return
	if _toast_time > 0.0:
		_toast_time -= delta
		if _toast_time <= 0.0 and _toast:
			_toast.visible = false
	if _fps_on and _fps_label and _fps_label.visible:
		_fps_tick -= delta
		if _fps_tick <= 0.0:
			_fps_tick = 0.25
			var fps := Engine.get_frames_per_second()
			var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			var mem := int(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
			_fps_label.text = "FPS  %d\nDRAW %d\nMEM  %d MB" % [fps, draws, mem]
	if _freecam_on and not open and is_instance_valid(_freecam):
		_fly(delta)


func _input(event: InputEvent) -> void:
	if not _enabled:
		return
	if event is InputEventScreenTouch and event.pressed and _touch_ok():
		_note_touch(event)
		return
	if event is InputEventMouseMotion and _freecam_on and not open and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_freecam_yaw -= event.relative.x * 0.003
		_freecam_pitch = clampf(_freecam_pitch - event.relative.y * 0.0022, -1.2, 1.2)
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	if _is_backtick(key):
		_set_open(not open)
		get_viewport().set_input_as_handled()
		return
	if key.keycode == KEY_F12:
		capture_screenshot(1.0, key.shift_pressed)
		get_viewport().set_input_as_handled()
		return
	if not open:
		return
	if key.keycode == KEY_UP:
		_hist_step(-1)
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_DOWN:
		_hist_step(1)
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_TAB:
		_complete()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not _enabled or not open:
		return
	if event is InputEventMouseButton or event is InputEventKey or event is InputEventScreenTouch:
		get_viewport().set_input_as_handled()


func _touch_ok() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("ios") or DisplayServer.is_touchscreen_available()


func _note_touch(event: InputEventScreenTouch) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var kept: Array[float] = []
	for stamp in _touch_times:
		if now - stamp < 0.4:
			kept.append(stamp)
	kept.append(now)
	_touch_times = kept
	if _touch_times.size() >= 3:
		_touch_times.clear()
		_set_open(not open)


func _is_backtick(key: InputEventKey) -> bool:
	if key.shift_pressed or key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
		return false
	return key.keycode == KEY_QUOTELEFT or key.physical_keycode == KEY_QUOTELEFT or key.unicode == 96


func _set_open(on: bool) -> void:
	open = on
	if _layer:
		_layer.visible = on
	if on and _line:
		_line.grab_focus()
		_line.caret_column = _line.text.length()
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif _freecam_on and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_submit(text: String) -> void:
	var line := text.strip_edges()
	_line.clear()
	_hist_i = -1
	_draft = ""
	if line.is_empty():
		return
	_history.append(line)
	if _history.size() > 64:
		_history.remove_at(0)
	_echo("> " + line)
	_dispatch(line)


func _hist_step(dir: int) -> void:
	if _history.is_empty() or _line == null:
		return
	if _hist_i == -1:
		_draft = _line.text
		_hist_i = _history.size()
	_hist_i = clampi(_hist_i + dir, 0, _history.size())
	if _hist_i >= _history.size():
		_line.text = _draft
		_hist_i = -1
	else:
		_line.text = _history[_hist_i]
	_line.caret_column = _line.text.length()


func _complete() -> void:
	if _line == null:
		return
	var text := _line.text
	var parts: PackedStringArray = text.split(" ", false)
	if text.ends_with(" ") and parts.size() >= 1:
		_complete_arg(parts[0])
		return
	if parts.size() > 1:
		_complete_arg(parts[0])
		return
	var prefix := parts[0] if parts.size() == 1 else ""
	var matches: Array[String] = []
	for command_name in _commands.keys():
		var name := str(command_name)
		if name.begins_with(prefix):
			matches.append(name)
	matches.sort()
	if matches.is_empty():
		return
	if matches.size() == 1:
		_line.text = matches[0] + " "
		_line.caret_column = _line.text.length()
		return
	_echo("  ".join(matches))
	var common := matches[0]
	for name in matches:
		while not name.begins_with(common) and common.length() > 0:
			common = common.substr(0, common.length() - 1)
	_line.text = common
	_line.caret_column = common.length()


func _complete_arg(command_name: String) -> void:
	var options: PackedStringArray = PackedStringArray()
	match command_name:
		"tp":
			options = PackedStringArray(["planet", "moon", "ship", "cabin", "aisle"])
		"quality":
			options = PackedStringArray(["low", "med", "high"])
		"dither", "hud":
			options = PackedStringArray(["on", "off"])
		_:
			return
	var parts: PackedStringArray = _line.text.split(" ", false)
	var prefix := ""
	if not _line.text.ends_with(" ") and parts.size() > 1:
		prefix = parts[parts.size() - 1]
	var matches: Array[String] = []
	for option in options:
		if option.begins_with(prefix):
			matches.append(option)
	if matches.size() == 1:
		_line.text = command_name + " " + matches[0] + " "
		_line.caret_column = _line.text.length()
	elif matches.size() > 1:
		_echo("  ".join(matches))


func _dispatch(line: String) -> void:
	var parts: PackedStringArray = line.split(" ", false)
	if parts.is_empty():
		return
	var command_name := parts[0].to_lower()
	if not _commands.has(command_name):
		_echo("unknown command '%s'" % command_name, "err")
		return
	var entry: Dictionary = _commands[command_name]
	var callback: Callable = entry["call"]
	var args := PackedStringArray()
	for i in range(1, parts.size()):
		args.append(parts[i])
	callback.call(args)


func _cmd_help(args: PackedStringArray) -> void:
	if args.size() == 1:
		var command_name := args[0].to_lower()
		if not _commands.has(command_name):
			_echo("no help for '%s'" % command_name, "err")
			return
		var entry: Dictionary = _commands[command_name]
		_echo("%s  %s" % [command_name, str(entry["help"])])
		return
	var names: Array[String] = []
	for command_name in _commands.keys():
		names.append(str(command_name))
	names.sort()
	for command_name in names:
		var entry: Dictionary = _commands[command_name]
		_echo("%-12s %s" % [command_name, str(entry["help"])])


func _cmd_clear(_args: PackedStringArray) -> void:
	_lines.clear()
	if _log:
		_log.clear()


func _cmd_fps(_args: PackedStringArray) -> void:
	_fps_on = not _fps_on
	if _fps_label:
		_fps_label.visible = _fps_on and _hud_on
	_echo("fps %s" % ("on" if _fps_on else "off"))


func _cmd_tp(args: PackedStringArray) -> void:
	var scene := _scene()
	if scene == null or not scene.has_method("dev_teleport"):
		_echo("no flight scene", "err")
		return
	if args.is_empty():
		_echo("tp <planet|moon|ship|cabin|aisle> or tp x y z", "warn")
		return
	var spec := " ".join(args)
	var message := str(scene.dev_teleport(spec))
	_echo(message)


func _cmd_speed(args: PackedStringArray) -> void:
	var ship := _ship()
	if ship == null:
		_echo("no ship", "err")
		return
	if args.is_empty():
		_echo("speed x%s" % str(ship.get("dev_speed_mult")))
		return
	if not args[0].is_valid_float():
		_echo("speed needs a number", "err")
		return
	var mult := clampf(float(args[0]), 0.0, 20.0)
	ship.dev_speed_mult = mult
	_echo("speed x%s" % str(mult))


func _cmd_timescale(args: PackedStringArray) -> void:
	if args.is_empty():
		_echo("timescale %s" % str(Engine.time_scale))
		return
	if not args[0].is_valid_float():
		_echo("timescale needs a number", "err")
		return
	Engine.time_scale = clampf(float(args[0]), 0.0, 16.0)
	_echo("timescale %s" % str(Engine.time_scale))


func _cmd_freecam(_args: PackedStringArray) -> void:
	if _freecam_on:
		_freecam_off()
		_echo("freecam off")
		return
	var world := _world()
	if world == null:
		_echo("no world", "err")
		return
	var current := world.get_camera_3d()
	_freecam = Camera3D.new()
	_freecam.name = "DevFreecam"
	_freecam.fov = 60.0
	_freecam.near = 0.05
	_freecam.far = 7000.0
	if current:
		_freecam.global_transform = current.global_transform
		_freecam_pitch = current.global_rotation.x
		_freecam_yaw = current.global_rotation.y
	world.add_child(_freecam)
	_freecam.current = true
	_freecam_on = true
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_echo("freecam on  WASD move  mouse look  shift fast  ` for console")


func _freecam_off() -> void:
	_freecam_on = false
	if is_instance_valid(_freecam):
		_freecam.current = false
		_freecam.queue_free()
	_freecam = null
	var ship := _ship()
	if ship and ship.get("walking") == true and ship.get("_cabin") != null:
		var cabin = ship.get("_cabin")
		if cabin and cabin.walker and cabin.walker.eye:
			cabin.walker.eye.current = true
			return
	var world := _world()
	if world:
		var chase := world.get_node_or_null("ChaseCamera")
		if chase is Camera3D:
			chase.current = true


func _fly(delta: float) -> void:
	var speed := 18.0
	if Input.is_action_pressed("boost"):
		speed = 70.0
	var wish := Vector3.ZERO
	if Input.is_action_pressed("throttle_forward"):
		wish.z -= 1.0
	if Input.is_action_pressed("throttle_back"):
		wish.z += 1.0
	if Input.is_action_pressed("yaw_left"):
		wish.x -= 1.0
	if Input.is_action_pressed("yaw_right"):
		wish.x += 1.0
	if Input.is_action_pressed("lift"):
		wish.y += 1.0
	if Input.is_action_pressed("drop"):
		wish.y -= 1.0
	_freecam.rotation = Vector3(_freecam_pitch, _freecam_yaw, 0.0)
	if wish.length_squared() > 0.0:
		_freecam.global_position += _freecam.global_basis * wish.normalized() * speed * delta


func _cmd_god(_args: PackedStringArray) -> void:
	var ship := _ship()
	if ship == null:
		_echo("no ship", "err")
		return
	ship.dev_god = not bool(ship.dev_god)
	_echo("god %s" % ("on" if ship.dev_god else "off"))


func _cmd_quality(args: PackedStringArray) -> void:
	if args.is_empty():
		_echo("quality %s" % _POST.quality())
		return
	var tier := args[0].to_lower()
	if tier == "medium":
		tier = "med"
	if tier != "low" and tier != "med" and tier != "high":
		_echo("quality is low, med or high", "err")
		return
	_POST.runtime_quality = tier
	_echo("quality %s, reloading" % tier)
	get_tree().reload_current_scene()


func _cmd_scale(args: PackedStringArray) -> void:
	if args.is_empty():
		_echo("renderscale %s" % str(_POST.render_scale()))
		return
	if not args[0].is_valid_float():
		_echo("renderscale needs a number", "err")
		return
	var scale := clampf(float(args[0]), 0.3, 1.0)
	_POST.runtime_scale = scale
	_reapply_scale()
	_echo("renderscale %s" % str(scale))


func _cmd_dither(args: PackedStringArray) -> void:
	var scene := _scene()
	if args.is_empty():
		_echo("dither %s" % ("on" if _POST.dither_enabled() else "off"))
		return
	var on := args[0].to_lower() == "on"
	if args[0].to_lower() != "on" and args[0].to_lower() != "off":
		_echo("dither on|off", "err")
		return
	_POST.runtime_dither = 1 if on else 0
	if scene and scene.has_method("set_dither_enabled"):
		scene.set_dither_enabled(on)
	_echo("dither %s" % ("on" if on else "off"))


func _cmd_hud(args: PackedStringArray) -> void:
	if args.is_empty():
		_echo("hud %s" % ("on" if _hud_on else "off"))
		return
	if args[0].to_lower() != "on" and args[0].to_lower() != "off":
		_echo("hud on|off", "err")
		return
	_hud_on = args[0].to_lower() == "on"
	_apply_hud(_hud_on)
	_echo("hud %s" % ("on" if _hud_on else "off"))


func _cmd_seed(args: PackedStringArray) -> void:
	if args.is_empty():
		var system_id := str(GameState.system_id)
		var active := Universe.active_seed(system_id)
		_echo("seed %d  (%s)" % [active, system_id])
		return
	if not args[0].is_valid_int():
		_echo("seed needs an integer", "err")
		return
	Universe.debug_seed = int(args[0])
	_echo("seed %d, reloading" % Universe.debug_seed)
	get_tree().reload_current_scene()


func _cmd_reload(_args: PackedStringArray) -> void:
	_echo("reloading")
	get_tree().reload_current_scene()


func _cmd_shot(args: PackedStringArray) -> void:
	var scale := 1.0
	if args.size() >= 1:
		if not args[0].is_valid_float():
			_echo("screenshot [scale]", "err")
			return
		scale = clampf(float(args[0]), 1.0, 4.0)
	capture_screenshot(scale, false)


func _cmd_quit(_args: PackedStringArray) -> void:
	get_tree().quit()


func _apply_hud(on: bool) -> void:
	for node in get_tree().get_nodes_in_group("akari_hud"):
		if node is CanvasItem:
			(node as CanvasItem).visible = on
		elif node is Node3D:
			(node as Node3D).visible = on
	if _fps_label:
		_fps_label.visible = _fps_on and on


func _reapply_scale() -> void:
	var scene := _scene()
	if scene and scene.has_method("apply_render_scale"):
		scene.apply_render_scale()


func _show_toast(text: String) -> void:
	if _toast == null:
		return
	_toast.text = text
	_toast.visible = true
	_place_toast()
	_toast_time = 1.4


func _timestamp_path() -> String:
	var date := Time.get_datetime_dict_from_system()
	var stamp := "%04d%02d%02d_%02d%02d%02d" % [int(date.year), int(date.month), int(date.day), int(date.hour), int(date.minute), int(date.second)]
	return "user://screenshots/akari_%s.png" % stamp


func _ensure_parent(path: String) -> Error:
	if path.begins_with("user://"):
		var root := DirAccess.open("user://")
		if root == null:
			return DirAccess.get_open_error()
		return root.make_dir_recursive("screenshots")
	var dir := path.get_base_dir()
	if dir.is_empty():
		return OK
	var abs := DirAccess.open("user://")
	if abs == null:
		return FAILED
	return DirAccess.make_dir_recursive_absolute(dir)


func _echo(text: String, kind: String = "info") -> void:
	_push_line(text, kind)


func _push_line(text: String, kind: String) -> void:
	if not _enabled:
		return
	var color := GREEN
	if kind == "warn":
		color = WARN
	elif kind == "err":
		color = ERR
	var bb := "[color=#%s]%s[/color]" % [color.to_html(false), _escape(text)]
	_lines.append(bb)
	if _lines.size() > MAX_LINES:
		var kept: Array[String] = []
		for i in range(_lines.size() - 250, _lines.size()):
			kept.append(_lines[i])
		_lines = kept
		_rebuild_log()
		return
	if _log:
		_log.append_text(bb + "\n")


func _rebuild_log() -> void:
	if _log == null:
		return
	_log.clear()
	for line in _lines:
		_log.append_text(line + "\n")


func _escape(text: String) -> String:
	return text.replace("[", "[lb]")


func _scene() -> Node:
	return get_tree().current_scene


func _world() -> SubViewport:
	var scene := _scene()
	if scene == null:
		return null
	return scene.get_node_or_null("View/Frame/World") as SubViewport


func _ship() -> Node:
	var world := _world()
	if world == null:
		return null
	return world.get_node_or_null("Ship")


class LogSink extends Logger:
	var host: Node

	func _log_message(message: String, error: bool) -> void:
		if host and host.has_method("mirror_message"):
			host.mirror_message(message, error)

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if host and host.has_method("mirror_error"):
			host.mirror_error(rationale, code, error_type)
