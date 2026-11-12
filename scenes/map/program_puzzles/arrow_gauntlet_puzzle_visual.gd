extends Node2D
class_name ArrowGauntletPuzzleVisual

var definition: ArrowGauntletPuzzleDefinition
var treasure_claimed: bool = false
var _pulse_time: float = 0.0


func configure(new_definition: ArrowGauntletPuzzleDefinition) -> void:
	definition = new_definition
	queue_redraw()


func set_treasure_claimed(value: bool) -> void:
	treasure_claimed = value
	queue_redraw()


func _process(delta: float) -> void:
	_pulse_time += delta
	queue_redraw()


func _draw() -> void:
	if definition == null:
		return
	var tile_size: float = float(Constants.TILE_SIZE)
	_draw_path(tile_size)
	_draw_hedges(tile_size)
	_draw_emitters(tile_size)
	_draw_start(tile_size)
	if not treasure_claimed:
		_draw_treasure(Vector2(definition.treasure_offset) * tile_size, tile_size)


func _draw_path(tile_size: float) -> void:
	var half_width: float = float(definition.barrier_x_offset) * tile_size
	var half_height: float = float(definition.barrier_half_height) * tile_size
	draw_rect(
		Rect2(Vector2(-half_width, -half_height), Vector2(half_width * 2.0, half_height * 2.0)),
		Color(0.26, 0.18, 0.08, 0.34),
		true
	)
	draw_line(
		Vector2.ZERO + Vector2(0.0, -half_height),
		Vector2.ZERO + Vector2(0.0, half_height),
		Color(0.76, 0.58, 0.28, 0.35),
		6.0
	)


func _draw_hedges(tile_size: float) -> void:
	var hedge_color: Color = Color(0.06, 0.35, 0.1, 0.96)
	var outline_color: Color = Color(0.18, 0.58, 0.16, 1.0)
	for y_offset: int in range(-definition.barrier_half_height, definition.barrier_half_height + 1):
		for x_offset: int in [-definition.barrier_x_offset, definition.barrier_x_offset]:
			var center: Vector2 = Vector2(x_offset, y_offset) * tile_size
			draw_circle(center, tile_size * 0.42, hedge_color)
			draw_circle(center + Vector2(-10.0, -8.0), tile_size * 0.2, outline_color)
	for x_offset: int in range(-definition.barrier_x_offset, definition.barrier_x_offset + 1):
		var top_center: Vector2 = Vector2(x_offset, -definition.barrier_half_height) * tile_size
		draw_circle(top_center, tile_size * 0.42, hedge_color)
	if definition.start_offset.y >= definition.barrier_half_height:
		return
	for x_offset: int in range(-definition.barrier_x_offset, definition.barrier_x_offset + 1):
		if x_offset == definition.start_offset.x:
			continue
		var bottom_center: Vector2 = Vector2(x_offset, definition.barrier_half_height) * tile_size
		draw_circle(bottom_center, tile_size * 0.42, hedge_color)


func _draw_emitters(tile_size: float) -> void:
	for row: int in definition.hazard_row_offsets:
		for side: int in [-1, 1]:
			var center: Vector2 = Vector2(side * definition.emitter_x_offset, row) * tile_size
			var facing: float = 1.0 if side < 0 else -1.0
			draw_line(center, center + Vector2(facing * 28.0, 0.0), Color(0.35, 0.18, 0.06, 1.0), 8.0)
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(facing * 30.0, 0.0),
				center + Vector2(facing * 15.0, -10.0),
				center + Vector2(facing * 15.0, 10.0),
			]), Color(0.82, 0.72, 0.48, 1.0))


func _draw_start(tile_size: float) -> void:
	var center: Vector2 = Vector2(definition.start_offset) * tile_size
	draw_circle(center, tile_size * 0.38, Color(0.34, 0.82, 0.3, 0.24))
	draw_arc(center, tile_size * 0.38, 0.0, TAU, 24, Color(0.46, 1.0, 0.4, 0.92), 4.0)


func _draw_treasure(center: Vector2, tile_size: float) -> void:
	var pulse: float = 0.8 + sin(_pulse_time * 4.0) * 0.15
	draw_circle(center, tile_size * 0.52, Color(1.0, 0.76, 0.16, 0.2 * pulse))
	draw_rect(
		Rect2(center + Vector2(-24.0, -13.0), Vector2(48.0, 32.0)),
		Color(0.38, 0.18, 0.055, 1.0),
		true
	)
	draw_arc(center + Vector2(0.0, -12.0), 22.0, PI, TAU, 24, Color(0.94, 0.66, 0.12, 1.0), 7.0)
	draw_rect(Rect2(center + Vector2(-4.0, -2.0), Vector2(8.0, 13.0)), Color(1.0, 0.84, 0.2, 1.0), true)
