class_name Ships
extends RefCounted

## Ship catalog. Ported from shared/ships.js. Milestone 1 flies the starter hull.

const MANUFACTURERS = {
	"vektron": {"name": "Vektron Industries", "color": "#f08040", "motto": "HAUL MORE. EARN MORE."},
	"astra": {"name": "Astra Dynamics", "color": "#40a0f0", "motto": "THE STARS ARE YOURS."},
	"phantom": {"name": "Phantom Works", "color": "#a040d0", "motto": "THEY WON'T SEE YOU COMING."},
	"ironclad": {"name": "Ironclad Military", "color": "#50d060", "motto": "PEACE THROUGH FIREPOWER."},
	"drift": {"name": "Drift Collective", "color": "#d0d0d0", "motto": "..."},
}

const SHIPS = {
	"starter": {
		"id": "starter",
		"name": "Drifter MK-I",
		"manufacturer": "drift",
		"rarity": "common",
		"price": 0,
		"description": "A beat-up starter hull. Gets you from A to B.",
		"stats": {"cargo": 20, "speed": 1.0, "hull": 50, "firepower": 5, "fuel_efficiency": 1.0},
	},
	"vektron_hauler": {
		"id": "vektron_hauler",
		"name": "Vektron Hauler",
		"manufacturer": "vektron",
		"rarity": "common",
		"price": 2000,
		"description": "The backbone of interstellar trade. Massive cargo bay.",
		"stats": {"cargo": 80, "speed": 1.4, "hull": 80, "firepower": 5, "fuel_efficiency": 0.8},
	},
	"vektron_bulkhead": {
		"id": "vektron_bulkhead",
		"name": "Vektron Bulkhead",
		"manufacturer": "vektron",
		"rarity": "uncommon",
		"price": 8000,
		"description": "When one cargo bay isn't enough. Built like a flying warehouse.",
		"stats": {"cargo": 200, "speed": 1.8, "hull": 120, "firepower": 3, "fuel_efficiency": 0.6},
	},
	"astra_scout": {
		"id": "astra_scout",
		"name": "Astra Scout",
		"manufacturer": "astra",
		"rarity": "common",
		"price": 1500,
		"description": "Reliable explorer with balanced stats. A pilot's best friend.",
		"stats": {"cargo": 35, "speed": 0.9, "hull": 60, "firepower": 10, "fuel_efficiency": 1.2},
	},
	"astra_pathfinder": {
		"id": "astra_pathfinder",
		"name": "Astra Pathfinder",
		"manufacturer": "astra",
		"rarity": "uncommon",
		"price": 6000,
		"description": "Long-range exploration vessel. Fuel-efficient with solid cargo.",
		"stats": {"cargo": 60, "speed": 0.8, "hull": 70, "firepower": 15, "fuel_efficiency": 1.5},
	},
	"phantom_runner": {
		"id": "phantom_runner",
		"name": "Phantom Runner",
		"manufacturer": "phantom",
		"rarity": "common",
		"price": 2500,
		"description": "Fastest ship in the sector. Paper-thin hull though.",
		"stats": {"cargo": 15, "speed": 0.5, "hull": 30, "firepower": 8, "fuel_efficiency": 1.1},
	},
	"phantom_spectre": {
		"id": "phantom_spectre",
		"name": "Phantom Spectre",
		"manufacturer": "phantom",
		"rarity": "rare",
		"price": 15000,
		"description": "Ghost of the void. Blazing fast with teeth to match.",
		"stats": {"cargo": 25, "speed": 0.4, "hull": 40, "firepower": 25, "fuel_efficiency": 1.3},
	},
	"ironclad_sentry": {
		"id": "ironclad_sentry",
		"name": "Ironclad Sentry",
		"manufacturer": "ironclad",
		"rarity": "uncommon",
		"price": 5000,
		"description": "Military patrol vessel. Heavy armor, heavy guns.",
		"stats": {"cargo": 25, "speed": 1.1, "hull": 150, "firepower": 30, "fuel_efficiency": 0.9},
	},
	"ironclad_dreadnought": {
		"id": "ironclad_dreadnought",
		"name": "Ironclad Dreadnought",
		"manufacturer": "ironclad",
		"rarity": "rare",
		"price": 25000,
		"description": "Capital-class warship. Fear incarnate.",
		"stats": {"cargo": 40, "speed": 1.6, "hull": 300, "firepower": 60, "fuel_efficiency": 0.5},
	},
	"drift_nomad": {
		"id": "drift_nomad",
		"name": "Drift Nomad",
		"manufacturer": "drift",
		"rarity": "rare",
		"price": 20000,
		"description": "Origin unknown. Exceptional all-around performance.",
		"stats": {"cargo": 50, "speed": 0.6, "hull": 100, "firepower": 20, "fuel_efficiency": 1.4},
	},
	"drift_void_walker": {
		"id": "drift_void_walker",
		"name": "Drift Void Walker",
		"manufacturer": "drift",
		"rarity": "legendary",
		"price": 50000,
		"description": "They say it phases between dimensions. No one knows who built it.",
		"stats": {"cargo": 70, "speed": 0.3, "hull": 150, "firepower": 40, "fuel_efficiency": 2.0},
	},
}

const RARITY_COLORS = {
	"common": "#9a9a9a",
	"uncommon": "#50d060",
	"rare": "#40a0f0",
	"legendary": "#f0c040",
}

const SHIP_DEALERS = {
	"hub": ["starter", "vektron_hauler", "astra_scout", "phantom_runner"],
	"industrial": ["vektron_hauler", "vektron_bulkhead", "ironclad_sentry"],
	"trade": ["vektron_hauler", "astra_scout", "astra_pathfinder", "phantom_runner"],
	"frontier": ["phantom_runner", "phantom_spectre", "ironclad_sentry"],
	"military": ["ironclad_sentry", "ironclad_dreadnought", "astra_scout"],
	"unknown": ["drift_nomad", "drift_void_walker", "phantom_spectre"],
}


static func get_ship(ship_id: String) -> Dictionary:
	return SHIPS.get(ship_id, SHIPS.starter)


static func cargo_capacity(ship_id: String) -> int:
	var ship: Dictionary = get_ship(ship_id)
	return int(ship.stats.cargo)
