extends Node

## Pilot session. Milestone 1 starts in Sol aboard the starter ship.
## Later saves go to user:// as JSON in the web store shape:
## { "player": { name, credits, system_id, cargo, ship, discoveries, depleted }, "marketPrices": {}, "version": 1 }

var system_id := "sol"
var ship_id := "starter"
var credits := 1000
var cargo := {}
var discoveries := {}
var depleted: Array = []


func player_snapshot() -> Dictionary:
	return {
		"name": "",
		"credits": credits,
		"system_id": system_id,
		"cargo": cargo.duplicate(),
		"ship": ship_id,
		"discoveries": discoveries.duplicate(),
		"depleted": depleted.duplicate(),
	}
