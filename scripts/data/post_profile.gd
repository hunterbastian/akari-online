class_name PostProfile
extends RefCounted

## Dither and the 3D render scale. Project settings override the consts when present.

const DITHER_ENABLED := true
## Internal 3D resolution as a fraction of the window. UI stays at native size.
## The debug console `renderscale` overrides this at runtime.
const RENDER_SCALE := 0.6
## GameCube-style passes in film_dither.gdshader, 0 off to 1 full.
## DEFLICKER blends each pixel with the rows above and below (the console's copy filter).
## COMPOSITE is the composite cable: softer luma, chroma bleeding sideways, faint dot crawl.
## CRT is alternate-row scanlines. Off by default: on a 0.6 nearest upscale they alias.
const DEFLICKER := 1.0
const COMPOSITE := 0.7
const CRT := 0.0

## Runtime overrides from the debug console. They survive a scene reload.
static var runtime_quality := ""
static var runtime_scale := -1.0
static var runtime_dither := -1
## Console `post` overrides, -1 = use the consts.
static var runtime_post := {"deflicker": -1.0, "composite": -1.0, "crt": -1.0}
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


## Edge chromatic aberration. Off on low so phones only pay for the grade.
static func film_ca() -> float:
	if quality() == "high":
		return 0.002
	if quality() == "med":
		return 0.001
	return 0.0


## Strength of a GameCube pass: "deflicker", "composite" or "crt".
static func film_pass(pass_name: String) -> float:
	var value := float(runtime_post.get(pass_name, -1.0))
	if value >= 0.0:
		return clampf(value, 0.0, 1.0)
	# AKARI_POST_DEFLICKER=0 and friends, for side-by-side shots.
	var env := OS.get_environment("AKARI_POST_" + pass_name.to_upper())
	if env.is_valid_float():
		return clampf(float(env), 0.0, 1.0)
	var key := "akari/post/" + pass_name
	if ProjectSettings.has_setting(key):
		return clampf(float(ProjectSettings.get_setting(key)), 0.0, 1.0)
	match pass_name:
		"deflicker":
			return DEFLICKER
		"composite":
			return COMPOSITE
		"crt":
			return CRT
	return 0.0
