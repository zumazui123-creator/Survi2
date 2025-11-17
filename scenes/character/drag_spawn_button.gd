extends Button


func _get_drag_data(_at_position):
	print("_get_drag_data")
	var drag_data = "BUTTON_DRAGGED"

	# A preview that follows the mouse
	var preview := Button.new()
	preview.text = text

	#preview.disabled = true
	set_drag_preview(preview)

	return drag_data

func _can_drop_data(_at_position, _data):
	print("_can_drop_data")
	return false  # button cannot receive drops
