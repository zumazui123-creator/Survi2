extends Node2D
class_name ItemOfferingPuzzleVisual

enum SlotState {
	WAITING,
	ACCEPTED,
	WRONG,
	COMPLETED,
}

var slot_offsets: Array[Vector2i] = []
var slot_states: Array[int] = []
var slot_labels: Array[Label] = []
var _wrong_time_remaining: Dictionary[int, float] = {}
var _pulse_time: float = 0.0


func configure(
		origin_tile: Vector2i,
		offering_tiles: Array[Vector2i],
		required_items: PackedStringArray
	) -> void:
	for label: Label in slot_labels:
		if is_instance_valid(label):
			label.queue_free()
	slot_offsets.clear()
	slot_states.clear()
	slot_labels.clear()
	for index: int in range(offering_tiles.size()):
		var offset: Vector2i = offering_tiles[index] - origin_tile
		slot_offsets.append(offset)
		slot_states.append(SlotState.WAITING)
		_create_label(index, offset, String(required_items[index]))
	queue_redraw()


func mark_accepted(index: int) -> void:
	if index < 0 or index >= slot_states.size():
		return
	slot_states[index] = SlotState.ACCEPTED
	_update_label_color(index)
	queue_redraw()


func flash_wrong(index: int) -> void:
	if index < 0 or index >= slot_states.size() \
			or slot_states[index] == SlotState.ACCEPTED:
		return
	slot_states[index] = SlotState.WRONG
	_wrong_time_remaining[index] = 1.2
	_update_label_color(index)
	queue_redraw()


func mark_completed() -> void:
	_wrong_time_remaining.clear()
	for index: int in range(slot_states.size()):
		slot_states[index] = SlotState.COMPLETED
		_update_label_color(index)
	queue_redraw()


func _process(delta: float) -> void:
	_pulse_time += delta
	for index_value: Variant in _wrong_time_remaining.keys():
		var index: int = int(index_value)
		_wrong_time_remaining[index] = float(_wrong_time_remaining[index]) - delta
		if float(_wrong_time_remaining[index]) <= 0.0:
			_wrong_time_remaining.erase(index)
			slot_states[index] = SlotState.WAITING
			_update_label_color(index)
	queue_redraw()


func _create_label(index: int, offset: Vector2i, item_id: String) -> void:
	var tile_size: float = float(Constants.TILE_SIZE)
	var label: Label = Label.new()
	label.position = Vector2(offset) * tile_size + Vector2(-58.0, -28.0)
	label.size = Vector2(116.0, 56.0)
	label.text = "%d\n%s" % [index + 1, item_id]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03, 1.0))
	add_child(label)
	slot_labels.append(label)
	_update_label_color(index)


func _update_label_color(index: int) -> void:
	if index < 0 or index >= slot_labels.size() \
			or not is_instance_valid(slot_labels[index]):
		return
	var color: Color = Color(0.96, 0.96, 1.0, 1.0)
	match slot_states[index]:
		SlotState.ACCEPTED:
			color = Color(0.35, 1.0, 0.52, 1.0)
		SlotState.WRONG:
			color = Color(1.0, 0.3, 0.25, 1.0)
		SlotState.COMPLETED:
			color = Color(1.0, 0.82, 0.22, 1.0)
	slot_labels[index].add_theme_color_override("font_color", color)


func _draw() -> void:
	var tile_size: float = float(Constants.TILE_SIZE)
	var pulse: float = 0.72 + sin(_pulse_time * 3.0) * 0.12
	for index: int in range(slot_offsets.size()):
		var center: Vector2 = Vector2(slot_offsets[index]) * tile_size
		var color: Color = Color(0.82, 0.84, 0.9, pulse)
		match slot_states[index]:
			SlotState.ACCEPTED:
				color = Color(0.2, 0.9, 0.4, 0.96)
			SlotState.WRONG:
				color = Color(1.0, 0.15, 0.12, 0.96)
			SlotState.COMPLETED:
				color = Color(1.0, 0.68, 0.12, 0.98)
		draw_circle(center, tile_size * 0.47, Color(color.r, color.g, color.b, 0.14))
		draw_rect(
			Rect2(center - Vector2.ONE * tile_size * 0.38, Vector2.ONE * tile_size * 0.76),
			Color(0.12, 0.11, 0.16, 0.94),
			true
		)
		draw_rect(
			Rect2(center - Vector2.ONE * tile_size * 0.34, Vector2.ONE * tile_size * 0.68),
			color,
			false,
			4.0
		)
