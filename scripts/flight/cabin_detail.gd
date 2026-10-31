extends RefCounted

## Lived-in cabin dressing: ribs, dash, and a handful of low-poly props.
## Coordinates passed through cabin._v() are glTF meters.

const _GRATE := preload("res://assets/shaders/cabin_grate.gdshader")


static func apply(cabin) -> void:
	var white: Material = cabin._paint(Color(0.78, 0.768, 0.745), 0.3, 0.08)
	var panel: Material = cabin._paint(Color(0.55, 0.545, 0.52), 0.46, 0.12)
	var rib: Material = cabin._paint(Color(0.14, 0.145, 0.155), 0.42, 0.22)
	var cloth: Material = cabin._paint(Color(0.11, 0.11, 0.125), 0.78, 0.0)
	var dark: Material = cabin._paint(Color(0.08, 0.082, 0.09), 0.4, 0.18)
	_shell(cabin, panel, rib)
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


static func _shell(cabin, panel: Material, rib: Material) -> void:
	# Proud ribs over the flat shell, with off-white panels set back between them.
	for i in 4:
		var z := -0.15 - float(i) * 0.72
		cabin._box("RibL%d" % i, cabin._v(-0.96, 0.55, z), cabin._v(0.045, 1.85, 0.055), rib, false)
		cabin._box("RibR%d" % i, cabin._v(0.96, 0.55, z), cabin._v(0.045, 1.85, 0.055), rib, false)
		if i < 3:
			var pz := z - 0.36
			cabin._box("PanL%d" % i, cabin._v(-0.995, 0.55, pz), cabin._v(0.02, 1.15, 0.52), panel, false)
			cabin._box("PanR%d" % i, cabin._v(0.995, 0.55, pz), cabin._v(0.02, 1.15, 0.52), panel, false)
	for i in 3:
		var z := -0.4 - float(i) * 0.7
		cabin._box("RibCeil%d" % i, cabin._v(0.0, 1.5, z), cabin._v(1.7, 0.04, 0.05), rib, false)
		if i < 2:
			cabin._box("PanCeil%d" % i, cabin._v(0.0, 1.53, z - 0.35), cabin._v(1.35, 0.02, 0.48), panel, false)
	# Pipes and a cable run along the upper corners.
	cabin._cyl("PipeL", cabin._v(-0.82, 1.32, -1.15), 0.025, 2.1, Vector3(PI * 0.5, 0.0, 0.0), rib)
	cabin._cyl("PipeR", cabin._v(0.84, 1.28, -0.9), 0.018, 1.5, Vector3(PI * 0.5, 0.0, 0.0), rib)
	cabin._box("PipeJoint", cabin._v(-0.82, 1.32, -2.15), cabin._v(0.06, 0.06, 0.06), rib, false)
	for i in 5:
		var t := float(i) / 4.0
		var y := lerpf(1.42, 0.85, t)
		var x := lerpf(-0.55, -0.9, t)
		var z := lerpf(-0.7, -0.35, t)
		cabin._box("Cable%d" % i, cabin._v(x, y, z), cabin._v(0.02, 0.16, 0.02), rib, false)
	for i in 6:
		var z := -0.4 - float(i) * 0.35
		cabin._box("Rivet%d" % i, cabin._v(-0.93, 1.05, z), cabin._v(0.02, 0.02, 0.02), rib, false)


static func _ceiling_lights(cabin) -> void:
	cabin._glow("CeilStrip", cabin._v(0.0, 1.46, -1.15), cabin._v(0.08, 0.015, 1.35), Color(1.05, 0.9, 0.7))
	cabin._glow("CeilSpot", cabin._v(0.35, 1.47, -1.9), cabin._v(0.22, 0.012, 0.08), Color(1.1, 0.78, 0.45))


static func _seat(cabin, white: Material, cloth: Material, dark: Material) -> void:
	# Cushion forward of the hips. Backrest behind the eyes so it cannot cut the glass.
	cabin._box("Seat", cabin._v(0.0, -0.24, -1.52), cabin._v(0.5, 0.12, 0.42), cloth, false)
	cabin._box("Backrest", cabin._v(0.0, 0.08, -1.08), cabin._v(0.46, 0.62, 0.07), cloth, false)
	cabin._box("Headrest", cabin._v(0.0, 0.46, -1.06), cabin._v(0.28, 0.14, 0.06), cloth, false)
	var left: MeshInstance3D = cabin._box("HarnessL", cabin._v(-0.1, 0.02, -1.28), cabin._v(0.025, 0.48, 0.018), dark, false)
	left.rotation.x = 0.35
	var right: MeshInstance3D = cabin._box("HarnessR", cabin._v(0.1, 0.02, -1.28), cabin._v(0.025, 0.48, 0.018), dark, false)
	right.rotation.x = 0.35
	cabin._box("Buckle", cabin._v(0.0, -0.16, -1.4), cabin._v(0.08, 0.04, 0.05), white, false)
	# Jump seat, folded against the left wall, with one strap.
	cabin._box("JumpBack", cabin._v(-0.9, 0.15, -0.5), cabin._v(0.06, 0.42, 0.38), cloth, false)
	cabin._box("JumpStrap", cabin._v(-0.84, 0.12, -0.5), cabin._v(0.015, 0.28, 0.03), dark, false)


static func _dash(cabin, white: Material, dark: Material) -> void:
	# Slim console. The old tall box sat between the seat and the glass.
	cabin._box("Dash", cabin._v(0.0, -0.08, -2.28), cabin._v(1.32, 0.18, 0.58), white, false)
	cabin._box("DashLip", cabin._v(0.0, 0.02, -2.08), cabin._v(1.2, 0.035, 0.16), white, false)
	cabin._box("DashRail", cabin._v(0.0, 0.0, -2.5), cabin._v(1.28, 0.02, 0.03), dark, false)
	for i in 6:
		var x := -0.46 + float(i) * 0.1
		var up := i % 2 == 0
		cabin._box("Switch%d" % i, cabin._v(x, 0.08, -2.04), cabin._v(0.035, 0.055, 0.03), dark, false)
		var cap_y := 0.115 if up else 0.055
		var cap := Color(0.35, 1.15, 0.5) if up else Color(0.2, 0.22, 0.2)
		if i == 3:
			cap = Color(1.15, 0.55, 0.2)
		cabin._glow("SwitchCap%d" % i, cabin._v(x, cap_y, -2.02), cabin._v(0.028, 0.016, 0.024), cap)
	var buttons: Array[Color] = [
		Color(0.25, 0.9, 1.1),
		Color(1.1, 0.85, 0.35),
		Color(0.4, 1.0, 0.5),
		Color(0.95, 0.35, 0.25),
	]
	for i in buttons.size():
		var color: Color = buttons[i]
		cabin._glow("Button%d" % i, cabin._v(0.22 + float(i) * 0.09, 0.07, -2.0), cabin._v(0.04, 0.025, 0.04), color)
	cabin._box("ThrottleBase", cabin._v(0.52, 0.04, -2.12), cabin._v(0.1, 0.04, 0.16), dark, false)
	var lever: MeshInstance3D = cabin._box("Throttle", cabin._v(0.52, 0.12, -2.08), cabin._v(0.03, 0.16, 0.03), dark, false)
	lever.rotation.x = -0.7
	cabin._glow("ThrottleCap", cabin._v(0.52, 0.2, -2.0), cabin._v(0.04, 0.025, 0.04), Color(0.95, 0.85, 0.55))


static func _props(cabin, white: Material, dark: Material, cloth: Material) -> void:
	cabin._box("Locker", cabin._v(-0.9, 0.05, 0.02), cabin._v(0.16, 0.72, 0.42), dark, false)
	cabin._box("LockerSeam", cabin._v(-0.81, 0.12, 0.02), cabin._v(0.012, 0.5, 0.3), white, false)
	# Helmet on a hook.
	cabin._box("Hook", cabin._v(-0.9, 0.85, -0.55), cabin._v(0.08, 0.02, 0.04), dark, false)
	cabin._sphere("Helmet", cabin._v(-0.86, 0.72, -0.55), 0.09, white)
	cabin._box("Visor", cabin._v(-0.8, 0.74, -0.55), cabin._v(0.04, 0.05, 0.1), dark, false)
	# Mug, clipboard, sticker, extinguisher, cartridges.
	cabin._cyl("Mug", cabin._v(-0.62, -0.02, -0.42), 0.035, 0.07, Vector3.ZERO, white)
	cabin._box("Clipboard", cabin._v(-0.78, 0.35, -0.05), cabin._v(0.012, 0.22, 0.16), white, false)
	cabin._glow("Sticker", cabin._v(0.97, 0.7, -1.15), cabin._v(0.01, 0.1, 0.16), Color(0.95, 0.45, 0.18))
	cabin._glow("StickerB", cabin._v(-0.97, 0.55, -1.7), cabin._v(0.01, 0.06, 0.1), Color(0.35, 0.75, 0.95))
	cabin._cyl("Extinguisher", cabin._v(0.78, -0.05, 0.02), 0.05, 0.32, Vector3.ZERO, cabin._paint(Color(0.72, 0.16, 0.12), 0.45, 0.08))
	cabin._box("ExtHead", cabin._v(0.78, 0.14, 0.02), cabin._v(0.06, 0.05, 0.06), dark, false)
	for i in 5:
		var tape: Material = dark if i % 2 == 0 else white
		cabin._box("Tape%d" % i, cabin._v(-0.34 + float(i) * 0.045, 0.06, -2.18), cabin._v(0.03, 0.07, 0.055), tape, false)
	# Folded bunk strap so the bunk reads as a berth, not a slab.
	cabin._box("BunkStrap", cabin._v(0.68, -0.12, -0.45), cabin._v(0.5, 0.02, 0.04), cloth, false)


static func _lights(cabin) -> void:
	# One warm practical on every quality. The rest are the expensive set.
	cabin._omni(cabin._v(0.0, 1.25, -1.5), Color(1.0, 0.72, 0.42), 0.28, 1.6)
	if not cabin._high:
		return
	cabin._omni(cabin._v(0.0, 1.05, -1.7), Color(0.45, 0.62, 1.0), 0.32, 1.8)
	cabin._omni(cabin._v(0.0, 0.55, -1.95), Color(0.35, 0.9, 0.5), 0.22, 0.85)
	cabin._omni(cabin._v(-0.2, 0.9, -1.7), Color(1.0, 0.62, 0.32), 0.24, 1.05)
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
