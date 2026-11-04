extends RefCounted

## Footstep bob for the cabin camera. One stride is one full rise and fall.
## The head is lowest when a foot plants, and the amplitude eases in and out.

const STRIDE := 0.62
const CLANK_EVERY := 6

var phase := 0.0
var carry := 0.0
var steps := 0
var foot := false
var clank := false
var blend := 0.0


func advance(moved: float, delta: float, scale: float) -> Vector3:
	foot = false
	clank = false
	if scale <= 0.001:
		phase = 0.0
		carry = 0.0
		blend = 0.0
		return Vector3.ZERO
	var goal := 0.0
	if moved > 0.00005:
		goal = 1.0
		carry += moved
		if carry >= STRIDE:
			carry -= STRIDE
			steps += 1
			foot = true
			clank = steps % CLANK_EVERY == 0
		phase = carry / STRIDE * TAU
	blend = lerpf(blend, goal, 1.0 - exp(-FlightProfile.BOB_EASE * delta))
	if blend <= 0.001:
		return Vector3.ZERO
	var amount := scale * blend
	var bob := -cos(phase) * FlightProfile.BOB_HEIGHT * amount
	var sway := sin(phase) * FlightProfile.BOB_SWAY * amount
	var roll := sin(phase) * FlightProfile.BOB_ROLL * amount
	return Vector3(sway, bob, roll)
