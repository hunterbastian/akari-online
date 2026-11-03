extends RefCounted

## Distances for detail levels. World units from the object's origin.
## Mobile (iPhone, low quality) pulls the cheaper levels in closer.
## HYSTERESIS keeps a level from flipping on the boundary.

const HYSTERESIS := 18.0
const FADE := 48.0
const MOBILE_FADE := 28.0

const NEAR_END := 140.0
const MID_END := 520.0
const MOBILE_NEAR_END := 80.0
const MOBILE_MID_END := 240.0

const SHIP_DETAIL := 70.0
const MOBILE_SHIP_DETAIL := 36.0
const SHIP_FADE := 14.0

const GREEBLE_END := 48.0
const MOBILE_GREEBLE_END := 24.0
const GREEBLE_FADE := 10.0

const MOON_NEAR := 160.0
const MOBILE_MOON_NEAR := 80.0


static func enabled() -> bool:
	return OS.get_environment("AKARI_LOD") != "0"


static func mobile() -> bool:
	if OS.has_feature("mobile"):
		return true
	if OS.get_environment("AKARI_QUALITY") == "low":
		return true
	return false


static func near_end(is_mobile: bool) -> float:
	return MOBILE_NEAR_END if is_mobile else NEAR_END


static func mid_end(is_mobile: bool) -> float:
	return MOBILE_MID_END if is_mobile else MID_END


static func fade(is_mobile: bool) -> float:
	return MOBILE_FADE if is_mobile else FADE


static func ship_detail(is_mobile: bool) -> float:
	return MOBILE_SHIP_DETAIL if is_mobile else SHIP_DETAIL


static func greeble_end(is_mobile: bool) -> float:
	return MOBILE_GREEBLE_END if is_mobile else GREEBLE_END


static func moon_near(is_mobile: bool) -> float:
	return MOBILE_MOON_NEAR if is_mobile else MOON_NEAR


## 0 is the full mesh, 1 the middle, 2 the far mesh.
## previous < 0 skips hysteresis. A held level stays until the camera
## clears the boundary by HYSTERESIS, so the swap does not chatter.
static func level_for(distance: float, is_mobile: bool, previous: int) -> int:
	var near_d := near_end(is_mobile)
	var mid_d := mid_end(is_mobile)
	var raw := 2
	if distance < near_d:
		raw = 0
	elif distance < mid_d:
		raw = 1
	if previous < 0 or previous == raw:
		return raw
	if previous == 0 and distance < near_d + HYSTERESIS:
		return 0
	if previous == 2 and distance > mid_d - HYSTERESIS:
		return 2
	if previous == 1 and distance > near_d - HYSTERESIS and distance < mid_d + HYSTERESIS:
		return 1
	return raw


static func show_near(mesh: GeometryInstance3D, end: float, band: float) -> void:
	mesh.visibility_range_begin = 0.0
	mesh.visibility_range_begin_margin = 0.0
	mesh.visibility_range_end = end
	mesh.visibility_range_end_margin = band
	mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	mesh.extra_cull_margin = 0.0


static func show_mid(mesh: GeometryInstance3D, begin: float, end: float, band: float) -> void:
	mesh.visibility_range_begin = begin
	mesh.visibility_range_begin_margin = band
	mesh.visibility_range_end = end
	mesh.visibility_range_end_margin = band
	mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	mesh.extra_cull_margin = 0.0


static func show_far(mesh: GeometryInstance3D, begin: float, band: float) -> void:
	mesh.visibility_range_begin = begin
	mesh.visibility_range_begin_margin = band
	mesh.visibility_range_end = 0.0
	mesh.visibility_range_end_margin = 0.0
	mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	mesh.extra_cull_margin = 0.0


static func cull_after(mesh: GeometryInstance3D, end: float, band: float) -> void:
	show_near(mesh, end, band)
