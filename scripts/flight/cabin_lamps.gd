extends RefCounted

## Cabin light preset. The blend is about half a second. RED pulses after it arrives.

const BLEND := 0.16

var preset := ""
var tint := Color(1, 1, 1)
var gain := 1.0
var target_tint := Color(1, 1, 1)
var target_gain := 1.0
var pulse := false
var time := 0.0


func set_preset(name: String) -> bool:
	var next_tint := Color(1, 1, 1)
	var next_gain := 1.0
	var next_pulse := false
	match name:
		"warm":
			next_tint = Color(1.32, 0.7, 0.34)
			next_gain = 1.08
		"cold":
			next_tint = Color(0.62, 0.82, 1.28)
			next_gain = 1.12
		"red":
			next_tint = Color(1.4, 0.16, 0.12)
			next_gain = 0.95
			next_pulse = true
		"off":
			next_gain = 0.0
		_:
			return false
	preset = name
	target_tint = next_tint
	target_gain = next_gain
	pulse = next_pulse
	return true


func advance(delta: float) -> void:
	time += delta
	var u := 1.0 - exp(-delta / BLEND)
	tint = tint.lerp(target_tint, u)
	gain = lerpf(gain, target_gain, u)


func shown_gain() -> float:
	if not pulse:
		return gain
	return gain * (0.55 + 0.45 * (0.5 + 0.5 * sin(time * 1.7)))
