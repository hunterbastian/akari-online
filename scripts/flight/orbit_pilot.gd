extends RefCounted

## Circular orbit around a body. The ship eases onto it; nothing teleports.

const RATE := 0.11
const EASE := 1.15

var active := false
var center := Vector3.ZERO
var target_radius := 1.0
var radius_now := 1.0
var normal := Vector3.UP
var angle := 0.0
var radial0 := Vector3.FORWARD
var tangent0 := Vector3.RIGHT


func engage(pos: Vector3, vel: Vector3, body: Vector3, planet_radius: float) -> void:
	active = true
	center = body
	var offset := pos - body
	if offset.length() < planet_radius * 0.5:
		offset = Vector3(0.0, planet_radius * 0.15, planet_radius * 2.2)
	var current := offset.length()
	var low := planet_radius * 1.8
	var high := planet_radius * 3.4
	var sensible := planet_radius * 2.2
	if current < low or current > high:
		target_radius = sensible
	else:
		target_radius = current
	radius_now = current
	var radial := offset.normalized()
	var tangent := vel - radial * vel.dot(radial)
	if tangent.length() < 0.4:
		tangent = radial.cross(Vector3.UP)
	if tangent.length() < 0.1:
		tangent = radial.cross(Vector3.RIGHT)
	tangent = tangent.normalized()
	normal = radial.cross(tangent).normalized()
	radial0 = radial
	tangent0 = tangent
	angle = 0.0


func step(pos: Vector3, delta: float) -> Vector3:
	if not active:
		return Vector3.ZERO
	angle += RATE * delta
	radius_now = lerpf(radius_now, target_radius, 1.0 - exp(-0.28 * delta))
	var radial := (radial0 * cos(angle) + tangent0 * sin(angle)).normalized()
	var tangent := normal.cross(radial).normalized()
	var desired := tangent * (RATE * radius_now)
	var pull := (center + radial * radius_now - pos) * 0.55
	return desired + pull


func cancel_if(throttle: bool, turn: bool, boost: bool, stop: bool, walking: bool) -> bool:
	if not active:
		return false
	if stop or ((throttle or turn or boost) and not walking):
		active = false
		return true
	return false
