extends Node

## Presses interact the way the window does and checks the pilot stands up.

var _ship: Node
var _phase := 0


func setup(ship: Node) -> void:
	_ship = ship


func _process(_delta: float) -> void:
	_phase += 1
	if _phase == 3:
		var event := InputEventAction.new()
		event.action = "interact"
		event.pressed = true
		Input.parse_input_event(event)
		return
	if _phase < 8:
		return
	if not bool(_ship.get("walking")):
		push_error("E in flight should stand the pilot up into the cabin")
		get_tree().quit(1)
		return
	print("Stand up test passed.")
	get_tree().quit(0)
