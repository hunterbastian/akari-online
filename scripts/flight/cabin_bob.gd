extends RefCounted

## Gentle cabin walk. Scale 0 holds the head still. A stride plants a foot; every few steps clank.

const STRIDE := 0.62
const CLANK_EVERY := 6

var phase := 0.0
var carry := 0.0
var steps := 0
var foot := false
var clank := false


func advance(moved: float, delta: float, scale: float) -> Vector3:
	foot = false
	clank = false
	if scale <= 0.001:
		phase = 0.0
		carry = 0.0
		return Vector3.ZERO
	if moved <= 0.00005:
		phase = lerpf(phase, 0.0, 1.0 - exp(-6.0 * delta))
		return Vector3.ZERO
	phase += moved * 9.2
	carry += moved
	if carry >= STRIDE:
		carry -= STRIDE
		steps += 1
		foot = true
		clank = steps % CLANK_EVERY == 0
	var bob := sin(phase) * 0.016 * scale
	var sway := sin(phase * 0.5) * 0.006 * scale
	var roll := sin(phase * 0.5) * 0.008 * scale
	return Vector3(sway, bob, roll)
