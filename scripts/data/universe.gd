class_name Universe
extends RefCounted

## Seeded system contents, ported from shared/universe.js.
## RNG call order matches that file so Sol's planets stay the same.

const SYLLABLES = ["ae", "ka", "vel", "no", "sy", "ir", "um", "or", "lu", "dra", "xe", "mi", "sol", "qua", "rin", "va", "el", "na", "os", "the"]

const BIOMES = [
	{"id": "lush", "label": "Lush", "relief": 0.05, "colors": ["#3d7a4e", "#8aaa58", "#d4c47a", "#f6ead0"], "atmosphere": "#f0d2a4", "ring": "#e4c98a", "moon": "#f6ead4", "resources": ["food", "medicine"]},
	{"id": "ocean", "label": "Ocean", "relief": 0.03, "colors": ["#1e6a88", "#3eb0c4", "#c8eee4", "#f6d0b4"], "atmosphere": "#f0a888", "ring": "#f2d0b6", "moon": "#f7e6d6", "resources": ["food", "medicine"]},
	{"id": "desert", "label": "Desert", "relief": 0.042, "colors": ["#c45a38", "#e08848", "#f2c98a", "#f8e6c8"], "atmosphere": "#2f8f8a", "ring": "#e8b48a", "moon": "#f4e0c8", "resources": ["ore", "fuel"]},
	{"id": "ice", "label": "Ice", "relief": 0.036, "colors": ["#7ecfe2", "#c5eef4", "#f2fafa", "#f6e0d4"], "atmosphere": "#f0b5a4", "ring": "#f6d8cc", "moon": "#f8eee8", "resources": ["ore", "medicine"]},
	{"id": "volcanic", "label": "Volcanic", "relief": 0.058, "colors": ["#5c2a22", "#c45a38", "#ee7840", "#f6c4a0"], "atmosphere": "#e08868", "ring": "#f0a878", "moon": "#ead2c2", "resources": ["ore", "scrap"]},
	{"id": "anomalous", "label": "Anomalous", "relief": 0.048, "colors": ["#5a3488", "#c070c8", "#f0c0dc", "#f8e6d4"], "atmosphere": "#e6b48a", "ring": "#e8c8a8", "moon": "#f4dce8", "resources": ["luxuries", "scrap"]},
]

const LUMINOUS = ["lush", "ocean", "desert", "ice", "anomalous"]

const SKIES = {
	"hub": {"top": "#1a1028", "mid": "#e06a5c", "bottom": "#f2c394", "star": "#ffe1bf"},
	"industrial": {"top": "#1a0e0c", "mid": "#e25a32", "bottom": "#f0b06a", "star": "#ffd0a4"},
	"trade": {"top": "#071820", "mid": "#2a8f86", "bottom": "#d7c4a2", "star": "#fff0d2"},
	"frontier": {"top": "#160a18", "mid": "#b45ea8", "bottom": "#f0b7c4", "star": "#ffe4f2"},
	"military": {"top": "#0e1612", "mid": "#3e8f68", "bottom": "#d5e2c4", "star": "#e7f2dc"},
	"unknown": {"top": "#10141f", "mid": "#6d78c4", "bottom": "#d5d3ef", "star": "#e4e7ff"},
}

const BIOME_ID = {
	"lush": 0.0,
	"ocean": 1.0,
	"desert": 2.0,
	"ice": 3.0,
	"volcanic": 4.0,
	"anomalous": 5.0,
}


static func u32(value: int) -> int:
	return value & 0xFFFFFFFF


static func i32(value: int) -> int:
	value = u32(value)
	if value >= 0x80000000:
		return value - 0x100000000
	return value


static func xor32(a: int, b: int) -> int:
	return i32(u32(a) ^ u32(b))


static func or32(a: int, b: int) -> int:
	return i32(u32(a) | u32(b))


static func shr_u(value: int, bits: int) -> int:
	return u32(value) >> bits


static func imul(a: int, b: int) -> int:
	return i32(i32(a) * i32(b))


static func hash_string(text: String) -> int:
	var h := i32(2166136261)
	for i in text.length():
		h = xor32(h, text.unicode_at(i))
		h = imul(h, 16777619)
	return u32(h)


class Rng:
	var a: int

	func _init(seed: int) -> void:
		a = Universe.u32(seed)

	func nextf() -> float:
		a = Universe.i32(a)
		a = Universe.i32(a + 0x6D2B79F5)
		var t := Universe.imul(Universe.xor32(a, Universe.shr_u(a, 15)), Universe.or32(1, a))
		var mixed := Universe.imul(Universe.xor32(t, Universe.shr_u(t, 7)), Universe.or32(61, t))
		t = Universe.xor32(t + mixed, t)
		return float(Universe.u32(Universe.xor32(t, Universe.shr_u(t, 14)))) / 4294967296.0


static func biome_index(biome_id: String) -> float:
	return float(BIOME_ID.get(biome_id, 0.0))


## Debug console override. -1 keeps the system-id hash the web build matches.
static var debug_seed := -1


static func active_seed(system_id: String) -> int:
	if debug_seed >= 0:
		return debug_seed
	return hash_string(system_id)


static func generate_system(system: Dictionary) -> Dictionary:
	var rng := Rng.new(active_seed(str(system.id)))
	var sky: Dictionary = SKIES.get(system.type, SKIES.unknown)
	var count := 3 + int(floor(rng.nextf() * 2.0))
	var used_names := {}
	var used_biomes := {}
	var planets: Array = []
	var deposits: Array = []

	for i in count:
		var pool: Array = []
		for biome in BIOMES:
			if used_biomes.has(biome.id):
				continue
			if i > 0 or LUMINOUS.has(biome.id):
				pool.append(biome)
		var choices: Array = pool if not pool.is_empty() else BIOMES
		var biome: Dictionary = choices[int(floor(rng.nextf() * float(choices.size())))]
		used_biomes[biome.id] = true

		var angle := -PI / 2.0 + 0.42 + (float(i) / float(count)) * TAU + (rng.nextf() - 0.5) * 0.12
		var dist := 190.0 + float(i) * 250.0 + rng.nextf() * 20.0
		var position := Vector3(
			cos(angle) * dist,
			(rng.nextf() - 0.5) * dist * 0.05,
			sin(angle) * dist,
		)
		var radius := 24.0 + rng.nextf() * 10.0
		var id := "%s:%d" % [system.id, i]
		var resources: Array = (biome.resources as Array).duplicate()
		var rings := rng.nextf() > 0.64
		var planet_name := _pick_name(rng, used_names)
		var ring_tilt := Vector3(
			0.35 + rng.nextf() * 0.45,
			rng.nextf() * PI,
			(rng.nextf() - 0.5) * 0.35,
		)
		var seed := float(hash_string(id) % 997) / 97.0
		planets.append({
			"id": id,
			"name": planet_name,
			"biome": biome.id,
			"biomeLabel": biome.label,
			"relief": biome.relief,
			"position": position,
			"radius": radius,
			"colors": biome.colors,
			"atmosphere": biome.atmosphere,
			"ring": biome.ring,
			"moon": biome.moon,
			"rings": rings,
			"ringTilt": ring_tilt,
			"seed": seed,
			"resources": resources,
			"moons": _make_moons(biome, rings, seed),
		})

		var length := position.length()
		if length == 0.0:
			length = 1.0
		var normal := position / length
		var tx := -normal.z
		var tz := normal.x
		for d in resources.size():
			var commodity_id: String = resources[d]
			var lateral := (-0.55 if d == 0 else 0.7) * radius * (0.65 + rng.nextf() * 0.35)
			var hover := radius + 9.0 + rng.nextf() * 8.0
			deposits.append({
				"id": "%s:%s" % [id, commodity_id],
				"planetId": id,
				"commodityId": commodity_id,
				"amount": 2 + int(floor(rng.nextf() * 2.0)),
				"position": Vector3(
					position.x - normal.x * hover + tx * lateral,
					position.y - normal.y * hover + (rng.nextf() - 0.5) * 3.0,
					position.z - normal.z * hover + tz * lateral,
				),
			})

	var stations: Array = system.get("stations", [])
	var station_name: String = stations[0] if not stations.is_empty() else "Station"
	return {
		"id": system.id,
		"name": system.name,
		"sky": sky,
		"spawn": Vector3(0, 6, 48),
		"station": {
			"name": station_name,
			"position": Vector3(32, -1, 102),
		},
		"planets": planets,
		"deposits": deposits,
		"belt": _make_belt(hash_string(str(system.id))),
	}


## Moons come from the planet's own fields, never from the shared RNG, so the
## web-matched sequence above is untouched. Every world keeps its pale primary
## moon; ringed worlds also hold a small dark shepherd moon well outside the rings.
static func _make_moons(biome: Dictionary, rings: bool, seed: float) -> Array:
	var moons: Array = [{
		"kind": "primary",
		"radius": 0.16,
		"color": biome.moon,
		"roughness": 0.92,
		"craters": false,
	}]
	if rings:
		moons.append({
			"kind": "shepherd",
			"radius": 0.1,
			"orbit": 3.25,
			"inclination": -0.3 - fmod(seed * 7.0, 1.0) * 0.12,
			"lead": 1.2 + fmod(seed * 3.0, 1.0) * 0.25,
			"color": "#627389",
			"roughness": 0.97,
			"craters": true,
		})
	return moons


static func _pick_name(rng: Rng, used: Dictionary) -> String:
	var name := "World"
	for _attempt in 8:
		var parts := 2 + (1 if rng.nextf() > 0.82 else 0)
		var word := ""
		for _i in parts:
			word += SYLLABLES[int(floor(rng.nextf() * float(SYLLABLES.size())))]
		name = word.substr(0, 1).to_upper() + word.substr(1)
		if not used.has(name):
			break
	used[name] = true
	return name


static func _make_belt(seed: int) -> Array:
	var rng := Rng.new(xor32(seed, 0xBEE5))
	if rng.nextf() < 0.4:
		return []
	var rocks: Array = []
	var count := 16
	for i in count:
		var angle := (float(i) / float(count)) * TAU + rng.nextf() * 0.18
		var radius := 188.0 + rng.nextf() * 28.0
		rocks.append({
			"position": Vector3(cos(angle) * radius, (rng.nextf() - 0.5) * 8.0, sin(angle) * radius),
			"rotation": Vector3(rng.nextf() * PI, rng.nextf() * PI, 0.0),
			"scale": 0.35 + rng.nextf() * 0.85,
		})
	return rocks
