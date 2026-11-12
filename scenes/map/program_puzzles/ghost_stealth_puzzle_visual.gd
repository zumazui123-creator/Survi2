extends Node2D
class_name GhostStealthPuzzleVisual

var definition: GhostStealthPuzzleDefinition
var route_offsets: Array[Vector2i] = []
var guard_indices: PackedInt32Array = PackedInt32Array()
var guards: Array[GhostPuzzleGuardVisual] = []
var treasure_visible: bool = true
var completed: bool = false
var _pulse_time: float = 0.0


func configure(
		new_definition: GhostStealthPuzzleDefinition,
		new_route_offsets: Array[Vector2i],
		initial_indices: PackedInt32Array
	) -> void:
	definition = new_definition
	route_offsets.assign(new_route_offsets)
	guard_indices = initial_indices.duplicate()
	for guard: GhostPuzzleGuardVisual in guards:
		if is_instance_valid(guard):
			guard.queue_free()
	guards.clear()
	for guard_index: int in range(definition.guard_count):
		var guard: GhostPuzzleGuardVisual = GhostPuzzleGuardVisual.new()
		guard.name = "GhostGuard%d" % guard_index
		add_child(guard)
		guard.configure(definition.ghost_actor_id)
		guards.append(guard)
	_apply_guard_positions()
	queue_redraw()


func set_state(
		new_guard_indices: PackedInt32Array,
		new_treasure_visible: bool,
		new_completed: bool
	) -> void:
	guard_indices = new_guard_indices.duplicate()
	treasure_visible = new_treasure_visible
	completed = new_completed
	_apply_guard_positions()
	for guard: GhostPuzzleGuardVisual in guards:
		guard.set_guard_active(not completed)
	queue_redraw()


func _apply_guard_positions() -> void:
	if route_offsets.is_empty():
		return
	for guard_index: int in range(mini(guards.size(), guard_indices.size())):
		var route_index: int = posmod(guard_indices[guard_index], route_offsets.size())
		guards[guard_index].set_tile_offset(route_offsets[route_index])


func _process(delta: float) -> void:
	_pulse_time += delta
	queue_redraw()


func _draw() -> void:
	if definition == null:
		return
	if not completed:
		_draw_vision_fields()
	if treasure_visible and not completed:
		_draw_treasure()


func _draw_vision_fields() -> void:
	if route_offsets.is_empty():
		return
	var tile_size: float = float(Constants.TILE_SIZE)
	for guard_index: int in range(mini(guards.size(), guard_indices.size())):
		var route_index: int = posmod(guard_indices[guard_index], route_offsets.size())
		var next_index: int = (route_index + 1) % route_offsets.size()
		var guard_offset: Vector2i = route_offsets[route_index]
		var delta: Vector2i = route_offsets[next_index] - guard_offset
		var facing: Vector2i = Vector2i(signi(delta.x), signi(delta.y))
		for vision_offset: Vector2i in definition.get_vision_offsets(facing):
			var center: Vector2 = Vector2(guard_offset + vision_offset) * tile_size
			var alpha: float = 0.12 + sin(_pulse_time * 3.2) * 0.025
			var area: Rect2 = Rect2(
				center - Vector2.ONE * tile_size * 0.46,
				Vector2.ONE * tile_size * 0.92
			)
			draw_rect(area, Color(0.72, 0.28, 1.0, alpha), true)
			draw_rect(area, Color(0.88, 0.58, 1.0, 0.34), false, 2.0)


func _draw_treasure() -> void:
	var tile_size: float = float(Constants.TILE_SIZE)
	var center: Vector2 = Vector2(definition.treasure_offset) * tile_size
	var pulse: float = 0.82 + sin(_pulse_time * 4.0) * 0.12
	draw_circle(center, tile_size * 0.48, Color(1.0, 0.78, 0.18, 0.16 * pulse))
	draw_rect(
		Rect2(center + Vector2(-24.0, -13.0), Vector2(48.0, 32.0)),
		Color(0.38, 0.18, 0.055, 1.0),
		true
	)
	draw_arc(center + Vector2(0.0, -12.0), 22.0, PI, TAU, 24, Color(0.92, 0.62, 0.12, 1.0), 7.0)
	draw_rect(
		Rect2(center + Vector2(-4.0, -2.0), Vector2(8.0, 13.0)),
		Color(1.0, 0.82, 0.22, 1.0),
		true
	)
