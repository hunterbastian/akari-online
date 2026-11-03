extends RefCounted

## Cinematic thrust envelope. FOV, sway, and chase lag ease over a second and a half.
## No allocations; safe from a hot frame.

var fov_extra := 0.0
var thrust := 0.0
var phase := 0.0
var weight := 0.0
var push := 0.0
var lag := 0.0
var shake_amp := 0.0

var _fov_from := 0.0
var _fov_to := 0.0
var _fov_t := 1.0
var _fov_dur := 1.5
var _weight_from := 0.0
var _weight_to := 0.0
var _weight_t := 1.0
var _push_t := 10.0


# hot
func advance(amount: float, delta: float) -> void:
	var rise := amount - thrust
	thrust = amount
	phase += delta
	var goal := amount * FlightProfile.KICK_FOV
	if absf(goal - _fov_to) > 0.02:
		_fov_from = fov_extra
		_fov_to = goal
		_fov_t = 0.0
		_fov_dur = FlightProfile.KICK_IN_TIME if goal > fov_extra else FlightProfile.KICK_OUT_TIME
	_fov_t = minf(_fov_t + delta / _fov_dur, 1.0)
	var fov_u := _fov_t * _fov_t * (3.0 - 2.0 * _fov_t)
	fov_extra = lerpf(_fov_from, _fov_to, fov_u)
	if absf(amount - _weight_to) > 0.02:
		_weight_from = weight
		_weight_to = amount
		_weight_t = 0.0
	_weight_t = minf(_weight_t + delta / FlightProfile.SWAY_TIME, 1.0)
	var weight_u := _weight_t * _weight_t * (3.0 - 2.0 * _weight_t)
	weight = lerpf(_weight_from, _weight_to, weight_u)
	lag = weight
	shake_amp = FlightProfile.SHAKE_SWAY * weight
	if rise > 0.2:
		_push_t = 0.0
	_push_t += delta
	var inn := FlightProfile.PUSH_IN
	var out_t := FlightProfile.PUSH_OUT
	if _push_t < inn:
		var u := _push_t / inn
		push = u * u * (3.0 - 2.0 * u)
	elif _push_t < inn + out_t:
		var u := (_push_t - inn) / out_t
		u = u * u * (3.0 - 2.0 * u)
		push = 1.0 - u
	else:
		push = 0.0


# hot
func shake_offset(intensity: float) -> Vector3:
	if intensity <= 0.0 or (shake_amp <= 0.0 and push <= 0.0):
		return Vector3.ZERO
	var pitch := sin(phase * 0.62) * 0.62 + sin(phase * 1.05 + 1.1) * 0.38
	var yaw := sin(phase * 0.48 + 0.6) * 0.7 + sin(phase * 0.9 + 2.0) * 0.3
	var roll := sin(phase * 0.41 + 0.3) * 0.75 + sin(phase * 0.77) * 0.25
	var amp := shake_amp * intensity
	var nod := push * FlightProfile.PUSH_NOD * intensity
	return Vector3(pitch * amp + nod, yaw * amp * 0.55, roll * amp * 1.2)
