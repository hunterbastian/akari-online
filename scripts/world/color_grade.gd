class_name ColorGrade
extends RefCounted

## Destiny 1-style grade as a 16³ LUT. Godot samples a Texture3D as output = texture(input_rgb).
## Shadows lean blue-teal (near-black, not lifted), mids desaturate, highlights stay warm and small, contrast stays soft.

const SIZE := 16


static func build_lut() -> ImageTexture3D:
	var layers: Array = []
	for b in SIZE:
		var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
		for g in SIZE:
			for r in SIZE:
				var source := Vector3(
					float(r) / float(SIZE - 1),
					float(g) / float(SIZE - 1),
					float(b) / float(SIZE - 1),
				)
				var graded := grade(source)
				image.set_pixel(r, g, Color(graded.x, graded.y, graded.z))
		layers.append(image)
	var texture := ImageTexture3D.new()
	texture.create(Image.FORMAT_RGB8, SIZE, SIZE, SIZE, false, layers)
	return texture


static func grade(color: Vector3) -> Vector3:
	var softened := Vector3(_soft(color.x), _soft(color.y), _soft(color.z))
	var luma := _luma(softened)
	var mid := smoothstep(0.1, 0.38, luma) * (1.0 - smoothstep(0.62, 0.9, luma))
	var desat := 0.07 + mid * 0.18
	var graded := softened.lerp(Vector3.ONE * luma, desat)
	var shadow := 1.0 - smoothstep(0.0, 0.5, luma)
	graded.x += 0.006 * shadow
	graded.y += 0.024 * shadow
	graded.z += 0.052 * shadow
	var highlight := smoothstep(0.6, 1.0, luma)
	graded.x += 0.028 * highlight
	graded.y += 0.01 * highlight
	graded.z -= 0.014 * highlight
	return Vector3(
		clampf(graded.x, 0.0, 1.0),
		clampf(graded.y, 0.0, 1.0),
		clampf(graded.z, 0.0, 1.0),
	)


static func _soft(value: float) -> float:
	# Blacks stay near black (a faint blue tint comes from the shadow push above).
	var lifted := clampf(value, 0.0, 1.0) * 0.965 + 0.004
	return clampf((lifted - 0.5) * 0.98 + 0.5, 0.0, 1.0)


static func _luma(color: Vector3) -> float:
	return color.dot(Vector3(0.2126, 0.7152, 0.0722))
