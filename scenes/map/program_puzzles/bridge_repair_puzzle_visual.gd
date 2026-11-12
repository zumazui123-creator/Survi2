extends Node2D
class_name BridgeRepairPuzzleVisual

const WALL_TEXTURE: Texture2D = preload("res://assets/objects/mauer1.png")

var bridge_offsets: Array[Vector2i] = []
var gap_offsets: Array[Vector2i] = []
var repaired_offsets: Dictionary[Vector2i, bool] = {}
var treasure_offset: Vector2i
var bridge_repaired: bool = false
var treasure_claimed: bool = false
var _pulse_time: float = 0.0


func configure(
		center_tile: Vector2i,
		bridge_tiles: Array[Vector2i],
		gap_tiles: Array[Vector2i],
		new_treasure_tile: Vector2i
	) -> void:
	bridge_offsets.clear()
	gap_offsets.clear()
	repaired_offsets.clear()
	for tile: Vector2i in bridge_tiles:
		bridge_offsets.append(tile - center_tile)
	for tile: Vector2i in gap_tiles:
		gap_offsets.append(tile - center_tile)
	treasure_offset = new_treasure_tile - center_tile
	queue_redraw()


func mark_repaired(tile_offset: Vector2i) -> void:
	repaired_offsets[tile_offset] = true
	queue_redraw()


func set_state(is_bridge_repaired: bool, is_treasure_claimed: bool) -> void:
	bridge_repaired = is_bridge_repaired
	treasure_claimed = is_treasure_claimed
	queue_redraw()


func _process(delta: float) -> void:
	_pulse_time += delta
	queue_redraw()


func _draw() -> void:
	var tile_size: float = float(Constants.TILE_SIZE)
	for offset: Vector2i in bridge_offsets:
		var center: Vector2 = Vector2(offset) * tile_size
		var area: Rect2 = Rect2(
			center - Vector2.ONE * tile_size * 0.42,
			Vector2.ONE * tile_size * 0.84
		)
		if offset in gap_offsets and not repaired_offsets.has(offset):
			draw_rect(area, Color(0.08, 0.22, 0.38, 0.62), true)
			draw_rect(area, Color(1.0, 0.42, 0.2, 0.9), false, 4.0)
			draw_line(area.position, area.end, Color(1.0, 0.55, 0.22, 0.9), 4.0)
			draw_line(
				Vector2(area.end.x, area.position.y),
				Vector2(area.position.x, area.end.y),
				Color(1.0, 0.55, 0.22, 0.9),
				4.0
			)
		elif repaired_offsets.has(offset):
			draw_texture_rect(WALL_TEXTURE, area, false)
			draw_rect(area, Color(0.32, 0.38, 0.48, 0.18), true)
			draw_rect(area, Color(0.72, 0.74, 0.78, 1.0), false, 4.0)
		else:
			draw_rect(area, Color(0.42, 0.24, 0.08, 1.0), true)
			draw_line(
				Vector2(area.position.x, center.y),
				Vector2(area.end.x, center.y),
				Color(0.68, 0.42, 0.16, 1.0),
				3.0
			)
	if bridge_repaired and not treasure_claimed:
		_draw_treasure(Vector2(treasure_offset) * tile_size, tile_size)


func _draw_treasure(center: Vector2, tile_size: float) -> void:
	var pulse: float = 0.82 + sin(_pulse_time * 4.0) * 0.12
	draw_circle(center, tile_size * 0.48, Color(1.0, 0.78, 0.18, 0.18 * pulse))
	draw_rect(
		Rect2(center + Vector2(-24.0, -13.0), Vector2(48.0, 32.0)),
		Color(0.38, 0.18, 0.055, 1.0),
		true
	)
	draw_arc(
		center + Vector2(0.0, -12.0),
		22.0,
		PI,
		TAU,
		24,
		Color(0.92, 0.62, 0.12, 1.0),
		7.0
	)
	draw_rect(
		Rect2(center + Vector2(-4.0, -2.0), Vector2(8.0, 13.0)),
		Color(1.0, 0.82, 0.22, 1.0),
		true
	)
