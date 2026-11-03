class_name SixthLook
extends RefCounted

## PS2 / GameCube sixth-gen post stack, one film pass on the low-res world view.
##
## Each PASS_* switch takes that step out of every preset. Presets only choose
## which of the remaining steps run:
##   modern  Destiny grade as it ships (dither, grain, vignette, engine glow)
##   sixth   the full stack
##   phone   sixth without the two heavy steps (depth of field, god rays)
## A mobile machine, or quality "low", resolves "sixth" to the phone passes.
##
## The stack follows the sixth-gen notes (low internal res, Kawase bloom,
## distance blur, screen-space shafts, 5-bit ordered dither, GameCube vertical
## deflicker, composite chroma, light CRT). It lives in the film pass, after the
## sun glare, so the rings stay in frame. The blur keeps the ship sharp by testing
## the view ray. The Bayer already in film_dither is the one dither for the bit
## crush. Engine glow steps aside while Kawase is on.

const _Post := preload("res://scripts/data/post_profile.gd")

const PASS_LOWRES := true
const PASS_BLOOM := true
const PASS_DOF := true
const PASS_SHAFTS := true
const PASS_BITS := true
const PASS_DEFLICKER := true
const PASS_COMPOSITE := true
const PASS_CRT := true

## SubViewport height when the low-res pass is on. The frame nearest-upsamples
## it, so the Bayer stays on that pixel grid. scaling_3d would upscale before
## the film pass and smear the dither.
const INTERNAL_LINES := 480.0

## 5 bits per channel. The film shader's Bayer, added once before the floor, is the dither.
const BIT_STEPS := 32.0

const BLOOM := 0.85
const DOF := 0.4
const DOF_NEAR := 36.0
const DOF_FAR := 200.0
const SHAFTS := 0.62
const DEFLICKER := 0.82
const CHROMA := 0.66
const CRT := 0.5
const VIGNETTE := 0.22
## Cabin eye: no distance blur, and a light hand on the filters, so the green type stays readable.
const CABIN_BLOOM := 0.1
const CABIN_DEFLICKER := 0.16
const CABIN_CHROMA := 0.2
const CABIN_CRT := 0.22
const CABIN_SHAFTS := 0.18

static var preset := "modern"
static var lowres := 0.0
static var bloom := 0.0
static var dof := 0.0
static var shafts := 0.0
static var bits := 36.0
static var dither_extra := 0.01
static var deflicker := 0.0
static var chroma := 0.0
static var crt := 0.0
static var vignette := 0.14
static var engine_glow := 1.0
static var active := false


static func boot() -> void:
	var saved := "modern"
	if ProjectSettings.has_setting("akari/post/look"):
		saved = str(ProjectSettings.get_setting("akari/post/look")).to_lower()
	if saved != "sixth" and saved != "phone" and saved != "modern":
		saved = "modern"
	preset = saved
	_resolve()


static func set_preset(name: String) -> bool:
	var key := name.strip_edges().to_lower()
	if key != "modern" and key != "sixth" and key != "phone":
		return false
	preset = key
	_resolve()
	return true


## Negative means "use PostProfile.render_scale()".
static func scale_for(window_height: float) -> float:
	if lowres < 0.5:
		return -1.0
	var height := window_height
	if height < 2.0:
		height = 720.0
	return clampf(INTERNAL_LINES / height, 0.2, 1.0)


static func _heavy() -> bool:
	if preset != "sixth":
		return false
	if OS.has_feature("mobile"):
		return false
	return _Post.quality() != "low"


static func _resolve() -> void:
	active = preset != "modern"
	var heavy := _heavy()
	lowres = 1.0 if active and PASS_LOWRES else 0.0
	bloom = BLOOM if active and PASS_BLOOM else 0.0
	dof = DOF if heavy and PASS_DOF else 0.0
	shafts = SHAFTS if heavy and PASS_SHAFTS else 0.0
	if active and PASS_BITS:
		bits = BIT_STEPS
		dither_extra = 0.0
	else:
		bits = 36.0
		dither_extra = 0.01
	deflicker = DEFLICKER if active and PASS_DEFLICKER else 0.0
	chroma = CHROMA if active and PASS_COMPOSITE else 0.0
	crt = CRT if active and PASS_CRT else 0.0
	vignette = VIGNETTE if active and PASS_CRT else 0.14
	# Kawase replaces the engine glow so the two blooms do not stack.
	engine_glow = 0.0 if bloom > 0.01 else 1.0
