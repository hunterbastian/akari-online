extends SceneTree

## Inventory slots, lockers, and the save dictionary. No scene and no save file.


func _init() -> void:
	var failed := _run()
	if failed > 0:
		push_error("Inventory test failed (%d checks)." % failed)
		quit(1)
	else:
		print("Inventory tests passed.")
		quit(0)


func _run() -> int:
	var failed := 0
	var inv = load("res://scripts/flight/cabin_inventory.gd").new()
	inv.boot_empty()
	if not inv.give("cartridge", 1):
		push_error("give cartridge")
		failed += 1
	if not inv.give("cartridge", 2):
		push_error("stack cartridges on the selected slot")
		failed += 1
	inv.select(2)
	if not inv.give("crate", 1):
		push_error("give crate into the selected slot")
		failed += 1
	if not inv.give("helmet", 1):
		push_error("give helmet")
		failed += 1
	var hot: Array = inv.slots["hotbar"]
	var first: Dictionary = hot[0]
	var third: Dictionary = hot[2]
	if str(first["id"]) != "cartridge" or int(first["count"]) != 3:
		push_error("slot 1 is %s x%s" % [str(first["id"]), str(first["count"])])
		failed += 1
	if str(third["id"]) != "crate" or int(third["count"]) != 1:
		push_error("slot 3 is not the crate")
		failed += 1
	if not inv.store("LockerL", "mug", 1):
		push_error("store mug")
		failed += 1
	inv.transfer("hotbar", 2, "LockerL", 1)
	var locker: Array = inv.slots["LockerL"]
	var moved: Dictionary = locker[1]
	var emptied: Dictionary = hot[2]
	if str(moved["id"]) != "crate" or int(emptied["count"]) != 0:
		push_error("transfer into the locker")
		failed += 1
	var saved: Dictionary = inv.to_dict()
	var kinds := ["cartridge", "mug", "crate"]
	var n := 0
	for bank in ["hotbar", "pack"]:
		var row: Array = inv.slots[bank]
		for i in row.size():
			row[i] = {"id": kinds[n % 3], "count": 1}
			n += 1
	if inv.give("helmet", 1):
		push_error("full inventory accepted another helmet")
		failed += 1
	inv.clear_all()
	var cleared: Dictionary = hot[0]
	if int(cleared["count"]) != 0:
		push_error("clearinv left a hotbar item")
		failed += 1
	inv.from_dict(saved)
	var restored: Dictionary = inv.slots["hotbar"][0]
	if str(restored["id"]) != "cartridge" or int(restored["count"]) != 3:
		push_error("from_dict lost the cartridge stack")
		failed += 1
	var lines: PackedStringArray = inv.list_lines()
	if lines.is_empty():
		push_error("inv list empty")
		failed += 1
	inv.free()
	return failed
