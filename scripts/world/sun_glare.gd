extends CanvasLayer

## Screen-space sun glare: a soft core, an anamorphic streak, faint shafts and a few cool ghosts.
## Lives inside the low-res world view so the dither grid covers it. Hidden when Mina eclipses the sun.

const _PostProfile := preload("res://scripts/data/post_profile.gd")

var _view: SubViewport
var _sun_position := Vector3.ZERO
var _planet_center := Vector3.ZERO
var _planet_radius := 24.0
var _root: Control
var _core: TextureRect
var _streak: TextureRect
var _dirt: TextureRect
var _shafts: Array[TextureRect] = []
var _ghosts: Array[TextureRect] = []
var _ghost_spec := [
	[0.42, 0.10, Color(0.45, 0.62, 1.0, 0.07)],
	[0.78, 0.05, Color(0.62, 0.78, 1.0, 0.06)],
	[1.18, 0.16, Color(0.4, 0.55, 0.95, 0.045)],
	[1.55, 0.035, Color(0.9, 0.8, 0.62, 0.06)],
]
var _visibility := 0.0


func setup(view: SubViewport, sun_position: Vector3, planet_center: Vector3, planet_radius: float) -> void:
	_view = view
	_sun_position = sun_position
	_planet_center = planet_center
	_planet_radius = planet_radius
	layer = 0
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var high := _PostProfile.high_quality()

	_core = _sprite(_radial(Color(1.0, 0.62, 0.28, 0.55), Color(0.85, 0.32, 0.08, 0.0), 0.0), additive)
	if high:
		_streak = _sprite(_radial(Color(1.0, 0.55, 0.22, 0.5), Color(0.7, 0.28, 0.08, 0.0), 0.0), additive)
		_dirt = _sprite(_dirt_map(), additive)
		for i in 6:
			var shaft := _sprite(_linear_fade(Color(1.0, 0.95, 0.85, 0.07)), additive)
			shaft.pivot_offset = Vector2.ZERO
			_shafts.append(shaft)
	for spec in _ghost_spec:
		var tint: Color = spec[2]
		var ghost := _sprite(_radial(tint, Color(tint.r, tint.g, tint.b, 0.0), 0.55), additive)
		_ghosts.append(ghost)


func _sprite(texture: Texture2D, material: Material) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.material = material
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	_root.add_child(rect)
	return rect


func _radial(inner: Color, outer: Color, ring: float) -> GradientTexture2D:
	var gradient := Gradient.new()
	if ring > 0.0:
		gradient.offsets = PackedFloat32Array([0.0, ring, 0.8, 1.0])
		gradient.colors = PackedColorArray([Color(inner.r, inner.g, inner.b, inner.a * 0.35), inner, Color(outer.r, outer.g, outer.b, inner.a * 0.25), outer])
	else:
		gradient.offsets = PackedFloat32Array([0.0, 0.18, 1.0])
		gradient.colors = PackedColorArray([inner, Color(inner.r, inner.g, inner.b, inner.a * 0.3), outer])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	return texture


func _dirt_map() -> ImageTexture:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var specks: Array = [
		[18, 22, 7, Color(0.85, 0.78, 0.62, 0.22)],
		[40, 16, 4, Color(0.7, 0.78, 0.9, 0.16)],
		[46, 38, 9, Color(0.9, 0.84, 0.7, 0.14)],
		[24, 44, 5, Color(0.75, 0.8, 0.9, 0.12)],
		[12, 36, 3, Color(1.0, 0.95, 0.85, 0.18)],
	]
	for speck in specks:
		var cx: int = speck[0]
		var cy: int = speck[1]
		var radius: int = speck[2]
		var tint: Color = speck[3]
		for y in range(cy - radius, cy + radius + 1):
			for x in range(cx - radius, cx + radius + 1):
				if x < 0 or y < 0 or x > 63 or y > 63:
					continue
				var fall := 1.0 - Vector2(x - cx, y - cy).length() / float(radius)
				if fall <= 0.0:
					continue
				var pixel := image.get_pixel(x, y)
				pixel.r = maxf(pixel.r, tint.r)
				pixel.g = maxf(pixel.g, tint.g)
				pixel.b = maxf(pixel.b, tint.b)
				pixel.a = maxf(pixel.a, tint.a * fall)
				image.set_pixel(x, y, pixel)
	return ImageTexture.create_from_image(image)


func _linear_fade(color: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([color, Color(color.r, color.g, color.b, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0.0, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 8
	return texture


# hot
func _process(delta: float) -> void:
	if _view == null:
		return
	var camera := _view.get_camera_3d()
	var target := 0.0
	var screen := Vector2.ZERO
	var size := Vector2(_view.size)
	if camera and not camera.is_position_behind(_sun_position):
		screen = camera.unproject_position(_sun_position)
		var margin := size.y * 0.15
		var inside := Rect2(-Vector2.ONE * margin, size + Vector2.ONE * margin * 2.0).has_point(screen)
		if inside and not _eclipsed(camera.global_position):
			var center_dist := (screen - size * 0.5).length() / size.length()
			target = clampf(1.15 - center_dist * 1.2, 0.0, 1.0)
			# The combiner sits in the middle of the cabin view. Keep the glare off that glass.
			if camera.is_in_group("cabin_eye"):
				var glass := Rect2(size.x * 0.28, size.y * 0.26, size.x * 0.44, size.y * 0.46)
				if glass.has_point(screen):
					target = 0.0
				else:
					target *= 0.3
	# Quick in, slower out, so the glare does not pop when Mina's limb crosses the sun.
	var rate := 10.0 if target > _visibility else 4.0
	_visibility = lerpf(_visibility, target, 1.0 - exp(-rate * delta))
	_root.visible = _visibility > 0.01
	if not _root.visible:
		return
	var unit := size.y
	var core := 0.16 if camera != null and camera.is_in_group("cabin_eye") else 0.42
	_place(_core, screen, Vector2.ONE * unit * core, _visibility)
	var in_cabin := camera != null and camera.is_in_group("cabin_eye")
	if _streak:
		var streak_w := unit * (0.28 if in_cabin else 1.5)
		_place(_streak, screen, Vector2(streak_w, unit * 0.018), _visibility * 0.9)
	if _dirt:
		_dirt.visible = not in_cabin
		if not in_cabin:
			_place(_dirt, screen, Vector2.ONE * unit * 0.55, _visibility * 0.22)
	if in_cabin:
		for shaft in _shafts:
			shaft.visible = false
	else:
		_place_shafts(screen, unit)
	var axis := size * 0.5 - screen
	for i in _ghosts.size():
		var ghost := _ghosts[i]
		if in_cabin:
			ghost.visible = false
			continue
		var spec: Array = _ghost_spec[i]
		var at: Vector2 = screen + axis * float(spec[0]) * 2.0
		ghost.visible = true
		_place(ghost, at, Vector2.ONE * unit * float(spec[1]) * 2.0, _visibility)


func _place_shafts(screen: Vector2, unit: float) -> void:
	for i in _shafts.size():
		var shaft := _shafts[i]
		var angle := 0.35 + float(i) * TAU / float(_shafts.size()) + sin(float(i) * 3.7) * 0.4
		var length := unit * (0.32 + 0.12 * sin(float(i) * 1.9))
		shaft.size = Vector2(length, unit * 0.012)
		shaft.position = screen - Vector2(0.0, shaft.size.y * 0.5)
		shaft.pivot_offset = Vector2(0.0, shaft.size.y * 0.5)
		shaft.rotation = angle
		shaft.modulate = Color(1, 1, 1, _visibility)
		shaft.visible = true


func _place(rect: TextureRect, center: Vector2, extent: Vector2, alpha: float) -> void:
	rect.size = extent
	rect.position = center - extent * 0.5
	rect.modulate = Color(1, 1, 1, alpha)


func _eclipsed(origin: Vector3) -> bool:
	var to_sun := (_sun_position - origin).normalized()
	var oc := _planet_center - origin
	var along := oc.dot(to_sun)
	if along < 0.0:
		return false
	var closest := oc.length_squared() - along * along
	return closest < _planet_radius * _planet_radius * 1.02
