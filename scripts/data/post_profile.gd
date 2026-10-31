class_name PostProfile
extends RefCounted

## Dither and the 3D render scale. Project settings override the consts when present.

const DITHER_ENABLED := true
## Internal 3D resolution as a fraction of the window. UI stays at native size.
const RENDER_SCALE := 0.7

## Runtime overrides from the debug console. They survive a scene reload.
static var runtime_quality := ""
static var runtime_scale := -1.0
static var runtime_dither := -1
static var capture_boost := 1.0


static func dither_enabled() -> bool:
	if runtime_dither == 0 or runtime_dither == 1:
		return runtime_dither == 1
	if ProjectSettings.has_setting("akari/post/dither"):
		return bool(ProjectSettings.get_setting("akari/post/dither"))
	return DITHER_ENABLED


static func render_scale() -> float:
	var scale := RENDER_SCALE
	if runtime_scale > 0.0:
		scale = runtime_scale
	elif ProjectSettings.has_setting("akari/render/scale"):
		scale = float(ProjectSettings.get_setting("akari/render/scale"))
	scale *= capture_boost
	var cap := 4.0 if capture_boost > 1.01 else 1.0
	return clampf(scale, 0.25, cap)


## "high", "med" or "low". SSR, the reflection probe and the extra HUD taps
## stay on high. SSAO and the detailed cabin run on med and high.
## project.godot sets akari/quality.mobile="low", so iOS stays smooth unless
## the debug console sets a runtime override.
static func quality() -> String:
	if runtime_quality == "low" or runtime_quality == "med" or runtime_quality == "high":
		return runtime_quality
	var env := OS.get_environment("AKARI_QUALITY")
	if env == "low" or env == "med" or env == "high":
		return env
	var value := "high"
	if ProjectSettings.has_setting("akari/quality"):
		value = str(ProjectSettings.get_setting("akari/quality"))
	if value == "medium":
		value = "med"
	var method := str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "forward_plus"))
	if method != "forward_plus" or OS.has_feature("mobile"):
		value = "low"
	if value == "low" or value == "med":
		return value
	return "high"


static func high_quality() -> bool:
	return quality() == "high"


static func detailed() -> bool:
	return quality() != "low"
