extends CanvasLayer

## Hotbar, pack slots, and the locker panel. CRT green on Silkscreen, nearest,
## with the same Bayer dither as the debug console.

const _PIXEL := preload("res://scripts/ui/pixel_text.gd")
const _DITHER := preload("res://assets/shaders/console_dither.gdshader")
const _FONT := "res://assets/fonts/Silkscreen-Regular.ttf"

const GREEN := Color(0.62, 1.0, 0.72)
const DIM := Color(0.45, 0.78, 0.52)

var _ship: Node
var _inv
var _root: Control
var _slots: Array[Control] = []
var _drag := {}
var _touch := false
var _font: FontFile


func bind(ship: Node) -> void:
	_ship = ship
	layer = 6
	add_to_group("akari_hud")
	_touch = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available() or OS.get_environment("AKARI_TOUCH") == "1"
	_font = load(_FONT)
	_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	_font.hinting = TextServer.HINTING_NONE
	_font.generate_mipmaps = false
	_font.oversampling = 1.0
	_root = Control.new()
	_root.name = "Inventory"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	get_viewport().size_changed.connect(_rebuild)
	visible = false


func _process(_delta: float) -> void:
	_inv = _inventory()
	var walking := _ship != null and bool(_ship.get("walking"))
	visible = walking and _inv != null
	if not visible or _inv == null:
		return
	if bool(_inv.dirty) and _drag.is_empty():
		_inv.dirty = false
		_rebuild()


func _inventory():
	if _ship == null:
		return null
	var cabin = _ship.get("_cabin")
	if cabin == null:
		return null
	return cabin.get("inventory")


func _rebuild() -> void:
	if _inv == null or _root == null:
		return
	for child in _root.get_children():
		_root.remove_child(child)
		child.free()
	_slots.clear()
	var view := get_viewport().get_visible_rect().size
	var slot := 72.0 if _touch else 52.0
	var gap := 8.0
	var bottom := view.y - (96.0 if _touch else 46.0)
	_add_row("hotbar", bottom - slot, slot, gap, view.x, true)
	_add_row("pack", bottom - slot * 2.0 - gap, slot, gap, view.x, false)
	var bank := str(_inv.open_bank)
	if bank != "":
		_add_panel(bank, bottom - slot * 3.0 - gap * 3.0 - 36.0, slot, gap, view.x)


func _add_panel(bank: String, top: float, slot: float, gap: float, width: float) -> void:
	var count := 4
	var row_w := count * slot + (count - 1) * gap
	var left := (width - row_w) * 0.5
	var panel := ColorRect.new()
	panel.position = Vector2(left - 16.0, top - 40.0)
	panel.size = Vector2(row_w + 32.0, slot + 56.0)
	panel.color = Color(0.02, 0.06, 0.035, 0.9)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dither := ShaderMaterial.new()
	dither.shader = _DITHER
	panel.material = dither
	_root.add_child(panel)
	var rule := ColorRect.new()
	rule.position = panel.position
	rule.size = Vector2(panel.size.x, 2.0)
	rule.color = GREEN
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(rule)
	var title := _label(bank.to_upper(), 16)
	title.position = panel.position + Vector2(12.0, 8.0)
	title.size = Vector2(panel.size.x - 16.0, 24.0)
	title.add_theme_color_override("font_color", GREEN)
	_root.add_child(title)
	_fill_row(bank, left, top, slot, gap, false)


func _add_row(bank: String, top: float, slot: float, gap: float, width: float, numbered: bool) -> void:
	var row: Array = _inv.slots[bank]
	var row_w := row.size() * slot + (row.size() - 1) * gap
	var left := (width - row_w) * 0.5
	_fill_row(bank, left, top, slot, gap, numbered)


func _fill_row(bank: String, left: float, top: float, slot: float, gap: float, numbered: bool) -> void:
	var row: Array = _inv.slots[bank]
	for i in row.size():
		var data: Dictionary = row[i]
		var selected := numbered and i == int(_inv.selected)
		var box := ColorRect.new()
		box.position = Vector2(left + i * (slot + gap), top)
		box.size = Vector2(slot, slot)
		box.color = Color(0.03, 0.07, 0.04, 0.88)
		box.mouse_filter = Control.MOUSE_FILTER_STOP
		var dither := ShaderMaterial.new()
		dither.shader = _DITHER
		box.material = dither
		box.set_meta("bank", bank)
		box.set_meta("index", i)
		_root.add_child(box)
		_slots.append(box)
		var edge := ColorRect.new()
		edge.position = box.position
		edge.size = Vector2(slot, 2.0)
		edge.color = GREEN if selected else Color(DIM.r, DIM.g, DIM.b, 0.7)
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(edge)
		var text := "-"
		if int(data["count"]) > 0:
			text = str(_inv.KINDS[str(data["id"])])
			if int(data["count"]) > 1:
				text += "\nX%d" % int(data["count"])
		var name := _label(text, 16)
		name.position = box.position + Vector2(4.0, 8.0)
		name.size = Vector2(slot - 8.0, slot - 16.0)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name.add_theme_color_override("font_color", GREEN if int(data["count"]) > 0 else DIM)
		_root.add_child(name)
		if numbered:
			var key := _label(str(i + 1), 16)
			key.position = box.position + Vector2(4.0, slot - 18.0)
			key.size = Vector2(slot - 8.0, 16.0)
			key.add_theme_color_override("font_color", DIM)
			_root.add_child(key)


func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", GREEN)
	return label


func _input(event: InputEvent) -> void:
	if not visible or _inv == null:
		return
	var pressed := false
	var released := false
	var at := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = event.pressed
		released = not event.pressed
		at = event.position
	elif event is InputEventScreenTouch:
		pressed = event.pressed
		released = not event.pressed
		at = event.position
	else:
		return
	if pressed:
		var hit := _slot_at(at)
		if hit.is_empty():
			return
		_drag = hit
		get_viewport().set_input_as_handled()
	elif released and not _drag.is_empty():
		var hit := _slot_at(at)
		if not hit.is_empty():
			_inv.transfer(str(_drag["bank"]), int(_drag["index"]), str(hit["bank"]), int(hit["index"]))
		_drag = {}
		get_viewport().set_input_as_handled()


func _slot_at(screen_pos: Vector2) -> Dictionary:
	for slot in _slots:
		if not is_instance_valid(slot):
			continue
		if slot.get_global_rect().has_point(screen_pos):
			return {"bank": str(slot.get_meta("bank")), "index": int(slot.get_meta("index"))}
	return {}
