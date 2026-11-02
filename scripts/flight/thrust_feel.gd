extends RefCounted

## Thrust envelope for the FOV kick and the camera hum. No allocations; safe from a hot frame.

var fov_extra := 0.0
var kick := 0.0
var thrust := 0.0
var phase := 0.0
var shake_amp := 0.0


# hot
func advance(amount: float, delta: float) -> void:
	var rise := amount - thrust
	kick *= exp(-FlightProfile.SHAKE_DECAY * delta)
	if rise > 0.08:
		kick = maxf(kick, clampf(rise, 0.0, 1.0))
	thrust = amount
	phase += delta
	shake_amp = FlightProfile.SHAKE_HUM * thrust + FlightProfile.SHAKE_BURST * kick
	var target := amount * FlightProfile.KICK_FOV
	var rate := FlightProfile.KICK_IN if target > fov_extra else FlightProfile.KICK_OUT
	fov_extra = FlightProfile.damp(fov_extra, target, rate, delta)


# hot
func shake_offset(intensity: float) -> Vector2:
	if intensity <= 0.0 or shake_amp <= 0.0:
		return Vector2.ZERO
	var x := sin(phase * 8.2) * 0.72 + sin(phase * 13.6 + 0.9) * 0.28
	var y := sin(phase * 6.5 + 0.4) * 0.68 + sin(phase * 11.3 + 1.6) * 0.32
	return Vector2(x, y) * shake_amp * intensity
