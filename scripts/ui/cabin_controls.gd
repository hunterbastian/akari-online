extends CanvasLayer

## Touch stand/sit button and a walk stick. Hidden on desktop; iOS and AKARI_TOUCH show it.

const _PIXEL := preload("res://scripts/ui/pixel_text.gd")

var _ship: Node
var _stick := Vector2.ZERO
var _look := Vector2.ZERO
var _touch := false
var _base: Control
var _knob: Control
var _button: Button
var _dragging := false
var _look_id := -1


func setup(ship: Node) -> void:
	_ship = ship
	layer = 5
	_touch = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available() or OS.get_environment("AKARI_TOUCH") == "1"
	_build_stick()
	_build_button()
	visible = _touch
	get_viewport().size_changed.connect(_layout)
	_layout()


func move_vector() -> Vector2:
	return _stick


func consume_look() -> Vector2:
	var amount := _look
	_look = Vector2.ZERO
	return amount


func _build_stick() -> void:
	_base = Control.new()
	_base.name = "Stick"
	_base.custom_minimum_size = Vector2(128, 128)
	add_child(_base)
	var ring := ColorRect.new()
	ring.color = Color(0.08, 0.1, 0.12, 0.45)
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base.add_child(ring)
	_knob = ColorRect.new()
	_knob.color = Color(0.75, 0.82, 0.78, 0.8)
	_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_knob.size = Vector2(48, 48)
	_base.add_child(_knob)
	_base.gui_input.connect(_on_stick)


func _build_button() -> void:
	_button = Button.new()
	_button.name = "Seat"
	_button.text = "E"
	_button.focus_mode = Control.FOCUS_NONE
	_button.add_theme_font_override("font", _PIXEL.font())
	_button.add_theme_font_size_override("font_size", 22)
	_button.add_theme_color_override("font_color", Color(0.62, 1.0, 0.7))
	_button.add_theme_color_override("font_hover_color", Color(0.8, 1.0, 0.85))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.07, 0.72)
	style.border_color = Color(0.45, 0.8, 0.55, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(2)
	_button.add_theme_stylebox_override("normal", style)
	_button.add_theme_stylebox_override("hover", style)
	_button.add_theme_stylebox_override("pressed", style)
	_button.pressed.connect(_on_seat)
	add_child(_button)


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var margin := 28.0
	_base.position = Vector2(margin, view.y - margin - 128.0)
	_base.size = Vector2(128, 128)
	_knob.position = (_base.size - _knob.size) * 0.5
	_button.position = Vector2(view.x - margin - 84.0, view.y - margin - 84.0)
	_button.size = Vector2(84, 84)


func _process(_delta: float) -> void:
	if not _touch or _ship == null:
		visible = false
		return
	var flying := bool(_ship.get("active"))
	visible = flying
	var walking := bool(_ship.get("walking"))
	_base.visible = walking
	_button.text = "SIT" if walking else "E"
	if not _dragging:
		_stick = Vector2.ZERO
		_knob.position = (_base.size - _knob.size) * 0.5


func _on_seat() -> void:
	if _ship and _ship.has_method("toggle_seat"):
		_ship.toggle_seat()


func _on_stick(event: InputEvent) -> void:
	var local := Vector2.ZERO
	var pressed := false
	var released := false
	if event is InputEventScreenTouch:
		pressed = event.pressed
		released = not event.pressed
		local = event.position
	elif event is InputEventScreenDrag:
		pressed = true
		local = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = event.pressed
		released = not event.pressed
		local = event.position
	elif event is InputEventMouseMotion and _dragging:
		pressed = true
		local = event.position
	else:
		return
	if released:
		_dragging = false
		_stick = Vector2.ZERO
		return
	if not pressed:
		return
	_dragging = true
	var offset := local - _base.size * 0.5
	var length := minf(offset.length(), 42.0)
	if offset.length() > 0.001:
		offset = offset.normalized() * length
	_knob.position = _base.size * 0.5 + offset - _knob.size * 0.5
	# Screen +Y is down. Forward is up the stick, which is -Z in the walker.
	_stick = Vector2(offset.x / 42.0, offset.y / 42.0)


func _input(event: InputEvent) -> void:
	if not visible or _ship == null or not bool(_ship.get("walking")):
		return
	var view := get_viewport().get_visible_rect().size
	if event is InputEventScreenDrag and event.position.x > view.x * 0.45:
		_look += event.relative
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and not event.pressed and event.index == _look_id:
		_look_id = -1
