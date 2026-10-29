extends Label


func _process(_delta: float) -> void:
	visible = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
