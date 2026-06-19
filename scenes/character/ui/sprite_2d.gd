extends Sprite2D


var dragging := false

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if get_rect().has_point(to_local(event.position)):
					dragging = true
			else:
				dragging = false

func _process(_delta):
	if dragging:
		global_position = get_global_mouse_position()
