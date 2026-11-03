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
var _hide_shot := false
var _font: FontFile
var _icons := {}


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
	_hide_shot = _beauty_shot()


func _beauty_shot() -> bool:
	var args := OS.get_cmdline_user_args()
	if args.has("--hull") or args.has("--mega") or args.has("--atmo") or args.has("--interior") or args.has("--exterior"):
		return true
	for arg in args:
		if str(arg).begins_with("mega") or str(arg).begins_with("atmo"):
			return true
	return false


func _process(_delta: float) -> void:
	if _hide_shot:
		visible = false
		return
	_inv = _inventory()
	var walking := _ship != null and bool(_ship.get("walking"))
	var seated := false
	var cabin = _inventory_cabin()
	if cabin != null:
		seated = not bool(cabin.get("show_hotbar"))
	visible = walking and _inv != null and not seated
	if not visible or _inv == null:
		return
	if bool(_inv.dirty) and _drag.is_empty():
		_inv.dirty = false
		_rebuild()


func _inventory_cabin():
	if _ship == null:
		return null
	return _ship.get("_cabin")


func _inventory():
	var cabin = _inventory_cabin()
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
	var slot := 84.0 if _touch else 68.0
	var gap := 10.0
	var bottom := view.y - (110.0 if _touch else 52.0)
	_add_row("hotbar", bottom - slot, slot, gap, view.x, true)
	_add_row("pack", bottom - slot * 2.0 - gap, slot, gap, view.x, false)
	var bank := str(_inv.open_bank)
	if bank != "":
		_add_panel(bank, view.x)


func _add_panel(bank: String, width: float) -> void:
	var slot := 132.0
	var gap := 18.0
	var count := 4
	var row_w := count * slot + (count - 1) * gap
	var left := (width - row_w) * 0.5
	var header := 56.0
	var top := 72.0
	var panel := ColorRect.new()
	panel.position = Vector2(left - 28.0, top)
	panel.size = Vector2(row_w + 56.0, header + slot + 28.0)
	panel.color = Color(0.02, 0.06, 0.035, 0.92)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dither := ShaderMaterial.new()
	dither.shader = _DITHER
	panel.material = dither
	_root.add_child(panel)
	var rule := ColorRect.new()
	rule.position = panel.position
	rule.size = Vector2(panel.size.x, 3.0)
	rule.color = GREEN
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(rule)
	var title := _label("LOCKER", 32)
	title.position = panel.position + Vector2(24.0, 12.0)
	title.size = Vector2(panel.size.x - 48.0, 36.0)
	title.add_theme_color_override("font_color", GREEN)
	_root.add_child(title)
	_fill_row(bank, left, top + header, slot, gap, false, true)


func _add_row(bank: String, top: float, slot: float, gap: float, width: float, numbered: bool) -> void:
	var row: Array = _inv.slots[bank]
	var row_w := row.size() * slot + (row.size() - 1) * gap
	var left := (width - row_w) * 0.5
	_fill_row(bank, left, top, slot, gap, numbered, false)


func slot_center(bank: String, index: int) -> Vector2:
	for slot in _slots:
		if not is_instance_valid(slot):
			continue
		if str(slot.get_meta("bank")) == bank and int(slot.get_meta("index")) == index:
			var rect := slot.get_global_rect()
			return rect.position + rect.size * 0.5
	return Vector2.ZERO


func _fill_row(bank: String, left: float, top: float, slot: float, gap: float, numbered: bool, locker: bool) -> void:
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
		edge.size = Vector2(slot, 3.0)
		edge.color = GREEN if selected else Color(DIM.r, DIM.g, DIM.b, 0.7)
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(edge)
		var kind := str(data["id"])
		var count := int(data["count"])
		if count > 0 and _inv.KINDS.has(kind):
			var icon_px := 48.0 if locker else 32.0
			var icon := TextureRect.new()
			icon.texture = _icon(kind)
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_SCALE
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.size = Vector2(icon_px, icon_px)
			icon.position = box.position + Vector2((slot - icon_px) * 0.5, 10.0 if locker else 8.0)
			_root.add_child(icon)
			if locker:
				var name := _label(str(_inv.KINDS[kind]), 16)
				name.position = box.position + Vector2(4.0, icon_px + 16.0)
				name.size = Vector2(slot - 8.0, 20.0)
				name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				_root.add_child(name)
				if count > 1:
					var num := _label("X%d" % count, 16)
					num.position = box.position + Vector2(4.0, icon_px + 36.0)
					num.size = Vector2(slot - 8.0, 20.0)
					num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					_root.add_child(num)
			elif count > 1:
				var num := _label(str(count), 16)
				num.position = box.position + Vector2(slot - 22.0, 6.0)
				num.size = Vector2(18.0, 18.0)
				_root.add_child(num)
		elif locker:
			var empty := _label("-", 16)
			empty.position = box.position + Vector2(4.0, slot * 0.4)
			empty.size = Vector2(slot - 8.0, 20.0)
			empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty.add_theme_color_override("font_color", DIM)
			_root.add_child(empty)
		if numbered:
			var key := _label(str(i + 1), 16)
			key.position = box.position + Vector2(4.0, slot - 20.0)
			key.size = Vector2(slot - 8.0, 16.0)
			key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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


func _icon(kind: String) -> Texture2D:
	if _icons.has(kind):
		return _icons[kind]
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	if kind == "helmet":
		_paint_helmet(image)
	elif kind == "mug":
		_paint_mug(image)
	elif kind == "cartridge":
		_paint_cartridge(image)
	else:
		_paint_crate_icon(image)
	var texture := ImageTexture.create_from_image(image)
	_icons[kind] = texture
	return texture


func _px(image: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x > 15 or y > 15:
		return
	image.set_pixel(x, y, color)


func _rect(image: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for yy in h:
		for xx in w:
			_px(image, x + xx, y + yy, color)


func _paint_helmet(image: Image) -> void:
	var shell := Color(0.82, 0.84, 0.86, 1)
	var visor := Color(0.12, 0.16, 0.2, 1)
	_rect(image, 5, 2, 6, 2, shell)
	_rect(image, 3, 4, 10, 6, shell)
	_rect(image, 8, 6, 5, 3, visor)
	_rect(image, 6, 10, 4, 2, shell)
	_px(image, 4, 5, Color(1, 1, 1, 1))


func _paint_mug(image: Image) -> void:
	var cup := Color(0.9, 0.88, 0.82, 1)
	var hole := Color(0.25, 0.22, 0.18, 1)
	_rect(image, 4, 3, 7, 2, cup)
	_rect(image, 5, 4, 5, 1, hole)
	_rect(image, 4, 5, 7, 8, cup)
	_rect(image, 11, 6, 2, 5, cup)
	_px(image, 13, 7, cup)
	_px(image, 13, 9, cup)


func _paint_cartridge(image: Image) -> void:
	var body := Color(0.22, 0.24, 0.28, 1)
	var label := Color(0.35, 0.9, 0.45, 1)
	_rect(image, 3, 2, 10, 12, body)
	_rect(image, 4, 5, 8, 3, label)
	_rect(image, 6, 10, 4, 1, Color(0.55, 0.58, 0.62, 1))
	_px(image, 4, 3, Color(0.7, 0.72, 0.75, 1))


func _paint_crate_icon(image: Image) -> void:
	var wood := Color(0.62, 0.46, 0.28, 1)
	var edge := Color(0.32, 0.22, 0.12, 1)
	_rect(image, 2, 2, 12, 12, wood)
	_rect(image, 2, 2, 12, 2, edge)
	_rect(image, 2, 12, 12, 2, edge)
	_rect(image, 2, 2, 2, 12, edge)
	_rect(image, 12, 2, 2, 12, edge)
	for i in 8:
		_px(image, 4 + i, 4 + i, edge)
		_px(image, 11 - i, 4 + i, edge)


func _slot_at(screen_pos: Vector2) -> Dictionary:
	for slot in _slots:
		if not is_instance_valid(slot):
			continue
		if slot.get_global_rect().has_point(screen_pos):
			return {"bank": str(slot.get_meta("bank")), "index": int(slot.get_meta("index"))}
	return {}
