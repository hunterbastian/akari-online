extends CanvasLayer

## Full-frame grade for the cabin camera only. The space view leaves this hidden.

const _SHADER := preload("res://assets/shaders/cabin_grade.gdshader")


func _ready() -> void:
	layer = 0
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = _SHADER
	rect.material = material
	add_child(rect)
	visible = false


func _process(_delta: float) -> void:
	var view := get_parent() as Viewport
	if view == null:
		visible = false
		return
	var camera := view.get_camera_3d()
	visible = camera != null and camera.is_in_group("cabin_eye")
