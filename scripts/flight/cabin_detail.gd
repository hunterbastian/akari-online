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
	cabin._glow("CeilStrip", cabin._v(0.0, 1.46, -1.15), cabin._v(0.08, 0.015, 1.35), Color(1.05, 0.9, 0.7))
	cabin._glow("CeilSpot", cabin._v(0.35, 1.47, -1.9), cabin._v(0.22, 0.012, 0.08), Color(1.1, 0.78, 0.45))


static func _seat(cabin, white: Material, cloth: Material, dark: Material) -> void:
	# Cushion forward of the hips. Backrest behind the eyes so it cannot cut the glass.
	_Blocks.retile(cabin._box("Seat", cabin._v(0.0, -0.24, -1.52), cabin._v(0.5, 0.12, 0.42), cloth, false), "bunk")
	_Blocks.retile(cabin._box("Backrest", cabin._v(0.0, 0.08, -1.08), cabin._v(0.46, 0.62, 0.07), cloth, false), "bunk")
	_Blocks.retile(cabin._box("Headrest", cabin._v(0.0, 0.46, -1.06), cabin._v(0.28, 0.14, 0.06), cloth, false), "bunk")
	var left: MeshInstance3D = cabin._box("HarnessL", cabin._v(-0.1, 0.02, -1.28), cabin._v(0.025, 0.48, 0.018), dark, false)
	left.rotation.x = 0.35
	_Blocks.retile(left, "bezel")
	var right: MeshInstance3D = cabin._box("HarnessR", cabin._v(0.1, 0.02, -1.28), cabin._v(0.025, 0.48, 0.018), dark, false)
	right.rotation.x = 0.35
	_Blocks.retile(right, "bezel")
	_Blocks.retile(cabin._box("Buckle", cabin._v(0.0, -0.16, -1.4), cabin._v(0.08, 0.04, 0.05), white, false), "panel")
	# Jump seat, folded on the left, forward of the rack.
	_Blocks.retile(cabin._box("JumpBack", cabin._v(-0.86, 0.12, -2.02), cabin._v(0.06, 0.42, 0.36), cloth, false), "bunk")
	_Blocks.retile(cabin._box("JumpStrap", cabin._v(-0.8, 0.1, -2.02), cabin._v(0.015, 0.28, 0.03), dark, false), "bezel")
	var jump := cabin.get_node_or_null(NodePath("JumpSeat")) as MeshInstance3D
	if jump:
		_Blocks.retile(jump, "bunk")


static func _dash(cabin, white: Material, dark: Material) -> void:
	# Slim console. Switches sit beside the terminal so they don't cover the glass.
	_Blocks.retile(cabin._box("Dash", cabin._v(0.0, -0.08, -2.28), cabin._v(1.32, 0.18, 0.58), white, false), "panel")
	_Blocks.retile(cabin._box("DashLip", cabin._v(0.0, 0.02, -2.08), cabin._v(1.2, 0.035, 0.16), white, false), "panel")
	_Blocks.retile(cabin._box("DashRail", cabin._v(0.0, 0.0, -2.5), cabin._v(1.28, 0.02, 0.03), dark, false), "bezel")
	for i in 4:
		var x := -0.62 + float(i) * 0.09
		var up := i % 2 == 0
		_Blocks.retile(cabin._box("Switch%d" % i, cabin._v(x, 0.08, -2.04), cabin._v(0.035, 0.055, 0.03), dark, false), "bezel")
		var cap_y := 0.115 if up else 0.055
		var cap := Color(0.35, 1.15, 0.5) if up else Color(0.2, 0.22, 0.2)
		if i == 3:
			cap = Color(1.15, 0.55, 0.2)
		cabin._glow("SwitchCap%d" % i, cabin._v(x, cap_y, -2.02), cabin._v(0.028, 0.016, 0.024), cap)
	var buttons: Array[Color] = [
		Color(0.25, 0.9, 1.1),
		Color(1.1, 0.85, 0.35),
		Color(0.4, 1.0, 0.5),
	]
	for i in buttons.size():
		var color: Color = buttons[i]
		cabin._glow("Button%d" % i, cabin._v(0.4 + float(i) * 0.08, 0.07, -2.02), cabin._v(0.04, 0.025, 0.04), color)
	_Blocks.retile(cabin._box("ThrottleBase", cabin._v(0.58, 0.04, -2.14), cabin._v(0.1, 0.04, 0.16), dark, false), "bezel")
	var lever: MeshInstance3D = cabin._box("Throttle", cabin._v(0.58, 0.12, -2.1), cabin._v(0.03, 0.16, 0.03), dark, false)
	lever.rotation.x = -0.7
	_Blocks.retile(lever, "bezel")
	cabin._glow("ThrottleCap", cabin._v(0.58, 0.2, -2.02), cabin._v(0.04, 0.025, 0.04), Color(0.95, 0.85, 0.55))


static func _props(cabin, white: Material, dark: Material, cloth: Material) -> void:
	var offwhite := _flat(Color(0.82, 0.8, 0.76))
	# Helmet on a hook above the wall rack.
	_Blocks.retile(cabin._box("Hook", cabin._v(-0.78, 1.02, -1.62), cabin._v(0.1, 0.025, 0.04), dark, false), "bezel")
	cabin._sphere("Helmet", cabin._v(-0.68, 0.88, -1.62), 0.09, offwhite)
	_Blocks.retile(cabin._box("Visor", cabin._v(-0.6, 0.9, -1.62), cabin._v(0.035, 0.05, 0.09), dark, false), "bezel")
	# Mug on the lower rack, clipboard on the locker, cartridges on the dash.
	cabin._cyl("Mug", cabin._v(-0.58, 0.56, -1.42), 0.035, 0.07, Vector3.ZERO, offwhite)
	_Blocks.retile(cabin._box("Clipboard", cabin._v(-0.46, 0.42, -0.4), cabin._v(0.16, 0.22, 0.012), white, false), "panel")
	cabin._glow("Sticker", cabin._v(0.8, 0.9, -1.25), cabin._v(0.012, 0.1, 0.16), Color(0.95, 0.45, 0.18))
	cabin._glow("StickerB", cabin._v(-0.8, 0.9, -0.75), cabin._v(0.012, 0.06, 0.1), Color(0.35, 0.75, 0.95))
	cabin._cyl("Extinguisher", cabin._v(0.42, -0.18, -1.05), 0.05, 0.32, Vector3.ZERO, cabin._paint(Color(0.72, 0.16, 0.12), 0.45, 0.08))
	_Blocks.retile(cabin._box("ExtHead", cabin._v(0.42, 0.02, -1.05), cabin._v(0.06, 0.05, 0.06), dark, false), "bezel")
	for i in 5:
		var tape: Material = dark if i % 2 == 0 else white
		var tape_mesh: MeshInstance3D = cabin._box("Tape%d" % i, cabin._v(0.36 + float(i) * 0.045, 0.08, -2.2), cabin._v(0.03, 0.07, 0.055), tape, false)
		_Blocks.retile(tape_mesh, "bezel" if i % 2 == 0 else "panel")
	_Blocks.retile(cabin._box("BunkStrap", cabin._v(0.72, -0.08, -1.42), cabin._v(0.46, 0.02, 0.04), cloth, false), "bezel")


static func _flat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.88
	mat.metallic = 0.02
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return mat


static func _lights(cabin) -> void:
	# Warm practical, a bay light so the door isn't a blue wash, and monitor spill.
	# The extra fill and the sun shaft stay on the detailed quality.
	cabin._omni(cabin._v(0.0, 1.25, -1.5), Color(1.0, 0.78, 0.55), 0.42, 1.8)
	cabin._omni(cabin._v(0.0, 0.95, -0.15), Color(0.82, 0.88, 0.96), 0.7, 2.4)
	cabin._omni(cabin._v(0.0, 0.5, -1.9), Color(0.35, 0.95, 0.5), 0.28, 1.2)
	if not cabin._high:
		return
	cabin._omni(cabin._v(0.0, 1.05, -1.7), Color(0.45, 0.62, 1.0), 0.22, 1.8)
	cabin._omni(cabin._v(-0.2, 0.9, -1.5), Color(1.0, 0.62, 0.32), 0.2, 1.05)
	var spot := SpotLight3D.new()
	spot.name = "SunShaft"
	spot.position = cabin._v(0.15, 1.42, -2.45)
	spot.light_color = Color(1.0, 0.94, 0.82)
	spot.light_energy = 1.6
	spot.spot_range = 2.4
	spot.spot_angle = 22.0
	spot.spot_attenuation = 0.6
	spot.shadow_enabled = false
	spot.light_specular = 0.35
	cabin.add_child(spot)
	spot.look_at(cabin.to_global(cabin._v(0.0, 0.35, -1.45)), Vector3.UP)
	var shaft := MeshInstance3D.new()
	shaft.name = "Shaft"
	var quad := QuadMesh.new()
	quad.size = Vector2(cabin._scale * 0.55, cabin._scale * 1.35)
	shaft.mesh = quad
	shaft.position = cabin._v(0.1, 0.85, -2.15)
	shaft.rotation = Vector3(0.9, 0.15, 0.0)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.albedo_color = Color(1.0, 0.92, 0.75, 0.045)
	shaft.material_override = material
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shaft.layers = cabin.INTERIOR_LAYER
	cabin.add_child(shaft)
