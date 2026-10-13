extends Node2D
class_name WorldLandmark

@export var landmark_id: StringName = &"":
	set(value):
		landmark_id = value
		queue_redraw()
@export var bounds_size_tiles: Vector2i = Vector2i(7, 7):
	set(value):
		bounds_size_tiles = Vector2i(maxi(value.x, 1), maxi(value.y, 1))
		queue_redraw()


func configure(id: StringName, size_tiles: Vector2i) -> void:
	landmark_id = id
	bounds_size_tiles = size_tiles


func _draw() -> void:
	var tile_size: float = float(Constants.TILE_SIZE)
	var extent: Vector2 = Vector2(bounds_size_tiles) * tile_size
	var area: Rect2 = Rect2(-extent * 0.5, extent)
	match landmark_id:
		&"golem_temple":
			_draw_temple(area, tile_size)
		&"desert_temple":
			_draw_desert_temple(area, tile_size)
		&"ruins", &"destroyed_village":
			_draw_ruins(area)
		&"cave", &"abandoned_mine":
			_draw_cave(area)
		&"abandoned_tower":
			_draw_tower(area, tile_size)
		&"graveyard":
			_draw_graveyard(area, tile_size)
		&"crystal_field":
			_draw_crystals(tile_size)
		&"bandit_camp":
			_draw_camp(area, Color(0.55, 0.12, 0.08, 1.0))
		&"merchant_camp":
			_draw_camp(area, Color(0.92, 0.65, 0.12, 1.0))
		&"bridge":
			_draw_bridge(area, tile_size)
		&"meteor_crater":
			_draw_meteor(area)
		&"magical_crater":
			_draw_magical_crater(area, tile_size)
		&"forest_heart", &"ancient_tree":
			_draw_forest_heart(area, tile_size)
		&"shipwreck":
			_draw_shipwreck(area, tile_size)
		&"frost_boss_arena":
			_draw_frost_arena(area, tile_size)


func _draw_temple(area: Rect2, tile_size: float) -> void:
	draw_rect(area, Color(0.27, 0.28, 0.3, 0.42), true)
	draw_arc(Vector2.ZERO, tile_size * 3.0, 0.0, TAU, 40, Color(0.65, 0.67, 0.72, 0.9), 5.0)
	draw_circle(Vector2.ZERO, tile_size * 0.75, Color(0.18, 0.2, 0.24, 0.95))


func _draw_desert_temple(area: Rect2, tile_size: float) -> void:
	draw_rect(area, Color(0.58, 0.34, 0.08, 0.25), true)
	var base: Rect2 = Rect2(
		Vector2(-tile_size * 3.5, -tile_size * 2.2),
		Vector2(tile_size * 7.0, tile_size * 4.4)
	)
	draw_rect(base, Color(0.78, 0.52, 0.2, 0.92), true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-tile_size * 4.0, -tile_size * 2.2),
		Vector2.ZERO + Vector2(0, -tile_size * 4.5),
		Vector2(tile_size * 4.0, -tile_size * 2.2),
	]), Color(0.92, 0.68, 0.28, 0.96))
	draw_circle(Vector2.ZERO, tile_size * 0.72, Color(0.2, 0.55, 0.72, 0.95))


func _draw_ruins(area: Rect2) -> void:
	draw_rect(area, Color(0.2, 0.18, 0.16, 0.18), true)
	draw_rect(Rect2(area.position + Vector2(12, 12), Vector2(area.size.x * 0.55, 10)), Color(0.38, 0.37, 0.35, 1.0), true)
	draw_rect(Rect2(area.end - Vector2(area.size.x * 0.4, 22), Vector2(area.size.x * 0.4 - 12, 10)), Color(0.3, 0.29, 0.28, 1.0), true)


func _draw_cave(area: Rect2) -> void:
	draw_circle(Vector2.ZERO, minf(area.size.x, area.size.y) * 0.32, Color(0.18, 0.16, 0.15, 1.0))
	draw_circle(Vector2(0, 8), minf(area.size.x, area.size.y) * 0.18, Color(0.025, 0.025, 0.035, 1.0))


func _draw_graveyard(area: Rect2, tile_size: float) -> void:
	draw_rect(area, Color(0.12, 0.16, 0.13, 0.25), true)
	for x: int in range(-2, 3):
		for y: int in range(-1, 2):
			var center: Vector2 = Vector2(x, y) * tile_size
			draw_rect(Rect2(center - Vector2(5, 8), Vector2(10, 16)), Color(0.42, 0.43, 0.45, 1.0), true)


func _draw_crystals(tile_size: float) -> void:
	for offset: Vector2 in [Vector2(-2, 0), Vector2(-1, -1), Vector2.ZERO, Vector2(1, 1), Vector2(2, -1)]:
		var center: Vector2 = offset * tile_size
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(0, -18), center + Vector2(9, 0),
			center + Vector2(0, 18), center + Vector2(-9, 0),
		]), Color(0.45, 0.72, 1.0, 0.9))


func _draw_camp(area: Rect2, color: Color) -> void:
	draw_rect(area, Color(0.22, 0.13, 0.07, 0.15), true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-34, 20), Vector2(0, -30), Vector2(34, 20),
	]), color)
	draw_circle(Vector2(50, 20), 12.0, Color(1.0, 0.35, 0.05, 0.85))


func _draw_bridge(area: Rect2, tile_size: float) -> void:
	var horizontal: bool = area.size.x >= area.size.y
	var length: float = area.size.x if horizontal else area.size.y
	var bridge_rect: Rect2 = Rect2(
		Vector2(-length * 0.5, -tile_size * 0.38) if horizontal else Vector2(-tile_size * 0.38, -length * 0.5),
		Vector2(length, tile_size * 0.76) if horizontal else Vector2(tile_size * 0.76, length)
	)
	draw_rect(bridge_rect, Color(0.42, 0.24, 0.08, 1.0), true)


func _draw_meteor(area: Rect2) -> void:
	var radius: float = minf(area.size.x, area.size.y) * 0.3
	draw_circle(Vector2.ZERO, radius, Color(0.11, 0.09, 0.08, 0.75))
	draw_circle(Vector2.ZERO, radius * 0.5, Color(0.46, 0.18, 0.08, 0.9))
	draw_circle(Vector2(-5, -5), radius * 0.24, Color(0.85, 0.45, 0.12, 1.0))


func _draw_forest_heart(area: Rect2, tile_size: float) -> void:
	draw_circle(
		Vector2.ZERO,
		minf(area.size.x, area.size.y) * 0.44,
		Color(0.08, 0.32, 0.12, 0.3)
	)
	draw_arc(
		Vector2.ZERO,
		tile_size * 5.5,
		0.0,
		TAU,
		48,
		Color(0.35, 0.92, 0.28, 0.72),
		5.0
	)
	for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_circle(direction * tile_size * 4.0, 15.0, Color(0.48, 1.0, 0.24, 0.9))
	draw_rect(
		Rect2(Vector2(-tile_size * 0.6, -tile_size * 2.4), Vector2(tile_size * 1.2, tile_size * 3.2)),
		Color(0.35, 0.18, 0.06, 1.0),
		true
	)
	draw_circle(Vector2(0, -tile_size * 2.5), tile_size * 2.2, Color(0.08, 0.48, 0.13, 0.95))


func _draw_tower(area: Rect2, tile_size: float) -> void:
	draw_circle(Vector2.ZERO, minf(area.size.x, area.size.y) * 0.44, Color(0.2, 0.18, 0.28, 0.24))
	draw_rect(
		Rect2(Vector2(-tile_size * 1.5, -tile_size * 2.2), Vector2(tile_size * 3.0, tile_size * 4.4)),
		Color(0.32, 0.31, 0.38, 0.95),
		true
	)
	draw_circle(Vector2(0, -tile_size * 2.2), tile_size * 1.7, Color(0.48, 0.22, 0.68, 0.9))
	draw_circle(Vector2.ZERO, tile_size * 0.38, Color(0.78, 0.42, 1.0, 0.95))


func _draw_shipwreck(area: Rect2, tile_size: float) -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(area.position.x * 0.7, tile_size),
		Vector2(area.end.x * 0.7, tile_size),
		Vector2(area.end.x * 0.48, tile_size * 2.4),
		Vector2(area.position.x * 0.48, tile_size * 2.4),
	]), Color(0.32, 0.17, 0.07, 0.95))
	draw_line(Vector2.ZERO, Vector2(0, -tile_size * 2.5), Color(0.28, 0.14, 0.05, 1.0), 8.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(5, -tile_size * 2.3),
		Vector2(5, -tile_size * 0.25),
		Vector2(tile_size * 1.7, -tile_size * 0.5),
	]), Color(0.74, 0.68, 0.48, 0.75))


func _draw_magical_crater(area: Rect2, tile_size: float) -> void:
	var radius: float = minf(area.size.x, area.size.y) * 0.35
	draw_circle(Vector2.ZERO, radius, Color(0.08, 0.25, 0.42, 0.72))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(0.5, 0.92, 1.0, 0.9), 6.0)
	for offset: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var center: Vector2 = offset * tile_size * 2.4
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(0, -22), center + Vector2(10, 8),
			center + Vector2(0, 18), center + Vector2(-10, 8),
		]), Color(0.42, 0.88, 1.0, 0.95))


func _draw_frost_arena(area: Rect2, tile_size: float) -> void:
	var radius: float = minf(area.size.x, area.size.y) * 0.43
	draw_circle(Vector2.ZERO, radius, Color(0.42, 0.72, 0.88, 0.22))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(0.76, 0.94, 1.0, 0.95), 10.0)
	draw_arc(Vector2.ZERO, radius - tile_size, 0.0, TAU, 64, Color(0.3, 0.64, 0.88, 0.72), 4.0)
	for index: int in range(8):
		var direction: Vector2 = Vector2.RIGHT.rotated(TAU * float(index) / 8.0)
		var center: Vector2 = direction * (radius - tile_size * 0.45)
		draw_circle(center, 10.0, Color(0.85, 0.98, 1.0, 1.0))
