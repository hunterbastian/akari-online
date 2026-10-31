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


## "high" or "low". Heavy lighting effects (SSR, SSAO, SDFGI, reflection probe,
## engine lights, lens flare streaks, dense particles) only run on high.
## project.godot sets akari/quality.mobile="low", so iOS and the Mobile renderer stay smooth.
static func quality() -> String:
	var env := OS.get_environment("AKARI_QUALITY")
	if env == "low" or env == "high":
		return env
	var value := "high"
	if ProjectSettings.has_setting("akari/quality"):
		value = str(ProjectSettings.get_setting("akari/quality"))
	var method := str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "forward_plus"))
	if method != "forward_plus" or OS.has_feature("mobile"):
		value = "low"
	return "low" if value == "low" else "high"


static func high_quality() -> bool:
	return quality() == "high"
