extends RefCounted

## Lived-in cabin dressing: ribs, dash, and a handful of low-poly props.
## Coordinates passed through cabin._v() are glTF meters.

const _GRATE := preload("res://assets/shaders/cabin_grate.gdshader")
const _Blocks := preload("res://scripts/flight/cabin_blocks.gd")


static func apply(cabin) -> void:
	var white: Material = _Blocks.material("panel")
	var cloth: Material = _Blocks.material("bunk")
	var dark: Material = _Blocks.material("bezel")
	_ceiling_lights(cabin)
	_seat(cabin, white, cloth, dark)
	_dash(cabin, white, dark)
	_props(cabin, white, dark, cloth)
	_Blocks.contact(cabin, Vector3(0.0, 0.0, -2.55), Vector2(0.7, 0.8))
	_Blocks.contact(cabin, Vector3(-1.2, 0.0, -2.2), Vector2(0.28, 0.28))
	_Blocks.contact(cabin, Vector3(-1.1, 0.0, -2.35), Vector2(0.2, 0.2))
	_Blocks.bake()
	_lights(cabin)


static func grate_material(high: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _GRATE
	material.set_shader_parameter("paint_color", Color(0.2, 0.21, 0.225))
	material.set_shader_parameter("normal_tex", _grate_normal())
	material.set_shader_parameter("dither_strength", 0.014 if high else 0.01)
	material.set_shader_parameter("roughness_base", 0.58)
	material.set_shader_parameter("metallic_base", 0.62)
	return material


static func _grate_normal() -> Texture2D:
	var n := 32
	var image := Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var fx := fmod(float(x), 8.0)
			var fy := fmod(float(y), 8.0)
			var dx := 0.0
			var dy := 0.0
			if fx < 1.2:
				dx = 0.55
			elif fx > 6.8:
				dx = -0.55
			if fy < 1.2:
				dy = 0.55
			elif fy > 6.8:
				dy = -0.55
			image.set_pixel(x, y, Color(dx * 0.5 + 0.5, dy * 0.5 + 0.5, 1.0))
	return ImageTexture.create_from_image(image)


static func _ceiling_lights(cabin) -> void:
	var bulbs: Array[Vector3] = [
		Vector3(0.0, 1.68, -0.15),
		Vector3(-0.55, 1.68, -0.9),
		Vector3(0.45, 1.68, -1.9),
		Vector3(0.0, 1.74, -3.05),
	]
	for i in bulbs.size():
		var at: Vector3 = bulbs[i]
		cabin._glow("Bulb%d" % i, cabin._v(at.x, at.y, at.z), cabin._v(0.16, 0.03, 0.08), Color(1.5, 1.08, 0.55))


static func _seat(cabin, white: Material, cloth: Material, dark: Material) -> void:
	# Cushion forward of the hips. Backrest behind the eyes so it cannot cut the glass.
	_Blocks.retile(cabin._box("Seat", cabin._v(0.0, -0.24, -2.67), cabin._v(0.5, 0.12, 0.42), cloth, false), "bunk", cabin._high)
	_Blocks.retile(cabin._box("Backrest", cabin._v(0.0, 0.08, -2.23), cabin._v(0.46, 0.62, 0.07), cloth, false), "bunk", cabin._high)
	_Blocks.retile(cabin._box("Headrest", cabin._v(0.0, 0.46, -2.21), cabin._v(0.28, 0.14, 0.06), cloth, false), "bunk")
	var left: MeshInstance3D = cabin._box("HarnessL", cabin._v(-0.1, 0.02, -2.43), cabin._v(0.025, 0.48, 0.018), dark, false)
	left.rotation.x = 0.35
	_Blocks.retile(left, "bezel")
	var right: MeshInstance3D = cabin._box("HarnessR", cabin._v(0.1, 0.02, -2.43), cabin._v(0.025, 0.48, 0.018), dark, false)
	right.rotation.x = 0.35
	_Blocks.retile(right, "bezel")
	_Blocks.retile(cabin._box("Buckle", cabin._v(0.0, -0.16, -2.55), cabin._v(0.08, 0.04, 0.05), white, false), "panel")
	_Blocks.retile(cabin._box("JumpBack", cabin._v(-1.35, 0.12, -3.15), cabin._v(0.06, 0.42, 0.36), cloth, false), "bunk")
	_Blocks.retile(cabin._box("JumpStrap", cabin._v(-1.28, 0.1, -3.15), cabin._v(0.015, 0.28, 0.03), dark, false), "bezel")
	var jump := cabin.get_node_or_null(NodePath("JumpSeat")) as MeshInstance3D
	if jump:
		_Blocks.retile(jump, "bunk")


static func _dash(cabin, white: Material, dark: Material) -> void:
	# Slim console. Switches sit beside the terminal so they don't cover the glass.
	_Blocks.retile(cabin._box("Dash", cabin._v(0.0, -0.08, -3.43), cabin._v(1.6, 0.18, 0.58), white, false), "panel", cabin._high)
	_Blocks.retile(cabin._box("DashLip", cabin._v(0.0, 0.02, -3.23), cabin._v(1.45, 0.035, 0.16), white, false), "panel")
	_Blocks.retile(cabin._box("DashRail", cabin._v(0.0, 0.0, -3.65), cabin._v(1.55, 0.02, 0.03), dark, false), "bezel")
	for i in 4:
		var x := -0.74 + float(i) * 0.07
		var up := i % 2 == 0
		_Blocks.retile(cabin._box("Switch%d" % i, cabin._v(x, 0.08, -3.22), cabin._v(0.035, 0.055, 0.03), dark, false), "bezel")
		var cap_y := 0.115 if up else 0.055
		var cap := Color(0.35, 1.15, 0.5) if up else Color(0.2, 0.22, 0.2)
		if i == 3:
			cap = Color(1.15, 0.55, 0.2)
		cabin._glow("SwitchCap%d" % i, cabin._v(x, cap_y, -3.17), cabin._v(0.028, 0.016, 0.024), cap)
	var buttons: Array[Color] = [
		Color(0.25, 0.9, 1.1),
		Color(1.1, 0.85, 0.35),
		Color(0.4, 1.0, 0.5),
	]
	for i in buttons.size():
		var color: Color = buttons[i]
		cabin._glow("Button%d" % i, cabin._v(0.58 + float(i) * 0.08, 0.07, -3.17), cabin._v(0.04, 0.025, 0.04), color)
	_Blocks.retile(cabin._box("ThrottleBase", cabin._v(0.70, 0.04, -3.32), cabin._v(0.1, 0.04, 0.16), dark, false), "bezel")
	var lever: MeshInstance3D = cabin._box("Throttle", cabin._v(0.70, 0.12, -3.28), cabin._v(0.03, 0.16, 0.03), dark, false)
	lever.rotation.x = -0.7
	_Blocks.retile(lever, "bezel")
	cabin._glow("ThrottleCap", cabin._v(0.70, 0.2, -3.20), cabin._v(0.04, 0.025, 0.04), Color(0.95, 0.85, 0.55))


static func _props(cabin, white: Material, dark: Material, cloth: Material) -> void:
	var offwhite := _flat(Color(0.82, 0.8, 0.76))
	# Helmet and mug live on the workbench, the spot meant for personal clutter.
	_Blocks.retile(cabin._box("Hook", cabin._v(-1.5, 1.35, -2.35), cabin._v(0.08, 0.025, 0.04), dark, false), "bezel")
	cabin._sphere("Helmet", cabin._v(-1.2, 0.16, -2.15), 0.09, offwhite)
	_Blocks.retile(cabin._box("Visor", cabin._v(-1.12, 0.18, -2.15), cabin._v(0.035, 0.05, 0.09), dark, false), "bezel")
	cabin._cyl("Mug", cabin._v(-1.05, 0.1, -2.35), 0.035, 0.07, Vector3.ZERO, offwhite)
	_Blocks.retile(cabin._box("Clipboard", cabin._v(-0.98, 0.7, -0.55), cabin._v(0.02, 0.22, 0.16), white, false), "panel")
	cabin._glow("Sticker", cabin._v(1.55, 1.1, -1.85), cabin._v(0.012, 0.12, 0.18), Color(0.72, 0.42, 0.22))
	cabin._glow("StickerB", cabin._v(-0.98, 1.4, -0.9), cabin._v(0.012, 0.08, 0.12), Color(0.55, 0.62, 0.48))
	cabin._cyl("Extinguisher", cabin._v(1.55, -0.12, 0.15), 0.05, 0.36, Vector3.ZERO, _flat(Color(0.62, 0.22, 0.16)))
	_Blocks.retile(cabin._box("ExtHead", cabin._v(1.55, 0.1, 0.15), cabin._v(0.06, 0.05, 0.06), dark, false), "bezel")
	for i in 5:
		var tape: Material = dark if i % 2 == 0 else white
		var tape_mesh: MeshInstance3D = cabin._box("Tape%d" % i, cabin._v(-0.74 + float(i) * 0.04, 0.08, -3.55), cabin._v(0.03, 0.07, 0.055), tape, false)
		_Blocks.retile(tape_mesh, "bezel" if i % 2 == 0 else "panel")
	_Blocks.retile(cabin._box("BunkStrap", cabin._v(1.28, -0.1, -1.85), cabin._v(0.5, 0.02, 0.04), cloth, false), "bezel")


static func _flat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return mat


static func _lights(cabin) -> void:
	# One hard ceiling shadow on high quality. Low and med stay on AO and contact blobs.
	if not cabin._high:
		return
	var spot := SpotLight3D.new()
	spot.name = "CeilShadow"
	spot.position = cabin._v(0.0, 2.55, -1.7)
	spot.light_color = Color(1.0, 0.98, 0.94)
	spot.light_energy = 0.8
	spot.spot_range = cabin._scale * 5.0
	spot.spot_angle = 62.0
	spot.spot_attenuation = 0.05
	spot.shadow_enabled = true
	spot.shadow_bias = 0.04
	spot.shadow_normal_bias = 0.8
	spot.shadow_blur = 0.0
	spot.light_specular = 0.0
	cabin.add_child(spot)
	spot.look_at(cabin.to_global(cabin._v(0.0, -0.2, -1.7)), Vector3.RIGHT)
