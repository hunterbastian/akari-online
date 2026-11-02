extends RefCounted

## Baked panel seams, greeble, and a red stencil. One small texture, sampled by the
## paint shader, so the hull silhouette stays the Blender mesh.

const _GLYPHS := {
	"A": "01110100011000111111100011000110001",
	"C": "01110100011000010000100011000101110",
	"I": "11111001000010000100001000010011111",
	"K": "10001100101010011000101001001010001",
	"N": "10001110011010110101100111000110001",
	"O": "01110100011000110001100011000101110",
	"T": "11111001000010000100001000010000100",
	"U": "10001100011000110001100011000101110",
	"0": "01110100011001110101110011000101110",
	"7": "11111000010001000100010000010000100",
	"-": "00000000000000011111000000000000000",
}


static func panel_texture() -> ImageTexture:
	var size := 128
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.96, 0.96, 0.95, 1.0))
	var cuts := [0, 14, 30, 46, 58, 78, 96, 110]
	for cut in cuts:
		_hline(image, cut, Color(0.28, 0.3, 0.33))
		_vline(image, cut, Color(0.28, 0.3, 0.33))
	# Small inset plates. They read as greeble once the texture tiles over the hull.
	var plates := [
		Rect2i(16, 4, 10, 6), Rect2i(62, 18, 12, 8), Rect2i(84, 34, 8, 8),
		Rect2i(8, 50, 14, 5), Rect2i(34, 66, 8, 10), Rect2i(100, 70, 12, 6),
		Rect2i(20, 88, 16, 6), Rect2i(70, 100, 10, 8),
	]
	for plate in plates:
		_fill(image, plate, Color(0.62, 0.64, 0.67))
		_rect(image, plate, Color(0.22, 0.24, 0.27))
	_rivets(image)
	var texture := ImageTexture.create_from_image(image)
	return texture


static func decal_texture() -> ImageTexture:
	var image := Image.create(96, 40, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var ink := Color(0.72, 0.1, 0.08, 1.0)
	_text(image, 4, 4, "AK-07", ink, 2)
	_text(image, 4, 24, "CAUTION", ink, 1)
	return ImageTexture.create_from_image(image)


static func _hline(image: Image, y: int, color: Color) -> void:
	if y < 0 or y >= image.get_height():
		return
	for x in image.get_width():
		image.set_pixel(x, y, color)


static func _vline(image: Image, x: int, color: Color) -> void:
	if x < 0 or x >= image.get_width():
		return
	for y in image.get_height():
		image.set_pixel(x, y, color)


static func _fill(image: Image, rect: Rect2i, color: Color) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
				image.set_pixel(x, y, color)


static func _rect(image: Image, rect: Rect2i, color: Color) -> void:
	for x in range(rect.position.x, rect.position.x + rect.size.x):
		if _inside(image, x, rect.position.y):
			image.set_pixel(x, rect.position.y, color)
		var bottom := rect.position.y + rect.size.y - 1
		if _inside(image, x, bottom):
			image.set_pixel(x, bottom, color)
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		if _inside(image, rect.position.x, y):
			image.set_pixel(rect.position.x, y, color)
		var right := rect.position.x + rect.size.x - 1
		if _inside(image, right, y):
			image.set_pixel(right, y, color)


static func _inside(image: Image, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height()


static func _rivets(image: Image) -> void:
	var dot := Color(0.34, 0.35, 0.38)
	for y in range(6, image.get_height(), 16):
		for x in range(6, image.get_width(), 16):
			if _inside(image, x, y):
				image.set_pixel(x, y, dot)


static func _text(image: Image, x: int, y: int, text: String, color: Color, scale: int) -> void:
	var cursor := x
	for i in text.length():
		var ch := text.substr(i, 1)
		if ch == " ":
			cursor += 4 * scale
			continue
		if not _GLYPHS.has(ch):
			cursor += 6 * scale
			continue
		var rows: String = _GLYPHS[ch]
		for row in 7:
			for col in 5:
				if rows.substr(row * 5 + col, 1) != "1":
					continue
				for sy in scale:
					for sx in scale:
						var px := cursor + col * scale + sx
						var py := y + row * scale + sy
						if _inside(image, px, py):
							image.set_pixel(px, py, color)
		cursor += 6 * scale
