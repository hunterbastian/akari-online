class_name PostProfile
extends RefCounted

## Dither and the 3D render scale. Project settings override the consts when present.

const DITHER_ENABLED := true
## Internal 3D resolution as a fraction of the window. UI stays at native size.
const RENDER_SCALE := 0.7


static func dither_enabled() -> bool:
	if ProjectSettings.has_setting("akari/post/dither"):
		return bool(ProjectSettings.get_setting("akari/post/dither"))
	return DITHER_ENABLED


static func render_scale() -> float:
	var scale := RENDER_SCALE
	if ProjectSettings.has_setting("akari/render/scale"):
		scale = float(ProjectSettings.get_setting("akari/render/scale"))
	return clampf(scale, 0.25, 1.0)
