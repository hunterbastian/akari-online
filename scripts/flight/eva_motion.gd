extends RefCounted

## Float step for a spacewalk. Inertia, a slow coast, and a soft spring inside 40 m.
## Stored vectors only. step() is the per-frame path.

const ACCEL := 1.35
const DAMP := 0.38
const SOFT := 32.0
const LIMIT := 40.0
const SPRING := 4.0
const MOTES_HIGH := 14
const MOTES_LOW := 4

var pos := Vector3.ZERO
var vel := Vector3.ZERO
var roll := 0.0
var time := 0.0


# hot
func step(wish: Vector3, dt: float) -> void:
	time += dt
	vel += wish * ACCEL * dt
	vel *= exp(-DAMP * dt)
	var dist := pos.length()
	if dist > SOFT and dist > 0.0001:
		var u := clampf((dist - SOFT) / (LIMIT - SOFT), 0.0, 1.8)
		var pull := u * u * SPRING
		vel -= (pos / dist) * pull * dt
	pos += vel * dt
	dist = pos.length()
	if dist > LIMIT:
		var outward := pos / dist
		pos = outward * LIMIT
		var out_speed := vel.dot(outward)
		if out_speed > 0.0:
			vel -= outward * out_speed
	var lateral := vel.x
	if lateral > 1.2:
		lateral = 1.2
	elif lateral < -1.2:
		lateral = -1.2
	var target := sin(time * 0.17) * 0.04 + lateral * 0.025
	roll = lerpf(roll, target, 1.0 - exp(-0.55 * dt))


static func drop_amount(elapsed: float) -> float:
	var u := clampf(elapsed / 1.0, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


static func mote_count(phone: bool) -> int:
	return MOTES_LOW if phone else MOTES_HIGH


## Rear-wall passage. An open bay ignores the rear box and keeps every other one.
static func wall_blocks(rear_open: bool, is_rear: bool, at_x: float, at_z: float, min_x: float, max_x: float, min_z: float, max_z: float, radius: float) -> bool:
	if is_rear and rear_open:
		return false
	if at_x > min_x - radius and at_x < max_x + radius and at_z > min_z - radius and at_z < max_z + radius:
		return true
	return false
