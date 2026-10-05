extends TextureRect

func _get_drag_data(pos):
	var data = self.tooltip_text
	var preview : TextureRect = TextureRect.new()
	preview.texture = self.texture
	#preview.tooltip_text
	#preview.tooltip_text = self.tooltip_text
	set_drag_preview(preview)
	return data
