extends ProgramPuzzleHandler
class_name GhostStealthPuzzleHandler

@export var definitions: Array[GhostStealthPuzzleDefinition] = []

var _definitions_by_landmark: Dictionary[StringName, GhostStealthPuzzleDefinition] = {}
var _puzzles: Array[GhostStealthPuzzleInstance] = []


func _ready() -> void:
	_rebuild_definition_index()


func load_landmarks(plans: Array[LandmarkPlan]) -> void:
	_rebuild_definition_index()
	if not is_instance_valid(world_map):
		return
	for plan: LandmarkPlan in plans:
		var definition: GhostStealthPuzzleDefinition = _definitions_by_landmark.get(
			plan.landmark_id
		) as GhostStealthPuzzleDefinition
		if definition != null:
			_create_puzzle(definition, plan)


func clear_handler() -> void:
	for puzzle: GhostStealthPuzzleInstance in _puzzles:
		if is_instance_valid(puzzle.visual):
			puzzle.visual.queue_free()
	_puzzles.clear()


func server_tick(delta: float) -> void:
	for puzzle: GhostStealthPuzzleInstance in _puzzles:
		if puzzle.completed:
			continue
		puzzle.movement_remaining -= delta
		if puzzle.movement_remaining <= 0.0:
			puzzle.movement_remaining += puzzle.definition.movement_interval_seconds
			puzzle.advance_guards()
			_set_puzzle_state.rpc(
				puzzle.puzzle_index,
				puzzle.guard_route_indices,
				puzzle.treasure_visible,
				false
			)
		if not puzzle.treasure_visible and not _has_player_nearby(puzzle):
			puzzle.treasure_visible = true
			_set_puzzle_state.rpc(
				puzzle.puzzle_index,
				puzzle.guard_route_indices,
				true,
				false
			)


func server_observe_player(
		_player: Survi2Player,
		peer_id: int,
		tile: Vector2i,
		_tile_changed: bool
	) -> void:
	for puzzle: GhostStealthPuzzleInstance in _puzzles:
		if puzzle.completed:
			continue
		_announce_if_nearby(puzzle, peer_id, tile)
		if not puzzle.treasure_visible:
			continue
		if _is_tile_seen(puzzle, tile):
			_fail_attempt(puzzle, peer_id)
			continue
		if tile == puzzle.treasure_tile:
			_complete_puzzle(puzzle, peer_id)


func sync_peer(peer_id: int) -> void:
	var snapshot: Array[Dictionary] = []
	for puzzle: GhostStealthPuzzleInstance in _puzzles:
		snapshot.append({
			"guard_indices": puzzle.guard_route_indices,
			"treasure_visible": puzzle.treasure_visible,
			"completed": puzzle.completed,
		})
	_sync_puzzle_snapshot.rpc(peer_id, snapshot)


func _rebuild_definition_index() -> void:
	_definitions_by_landmark.clear()
	for definition: GhostStealthPuzzleDefinition in definitions:
		if definition != null and definition.is_valid():
			_definitions_by_landmark[definition.landmark_id] = definition


func _create_puzzle(
		definition: GhostStealthPuzzleDefinition,
		plan: LandmarkPlan
	) -> void:
	var route_offsets: Array[Vector2i] = _build_route(definition.patrol_waypoints)
	if route_offsets.size() < 2:
		push_warning("GhostStealthPuzzleHandler: patrol route is too short")
		return
	var puzzle: GhostStealthPuzzleInstance = GhostStealthPuzzleInstance.new(
		_puzzles.size(), definition, plan
	)
	puzzle.route_offsets.assign(route_offsets)
	for offset: Vector2i in route_offsets:
		puzzle.route_tiles.append(plan.center_tile + offset)
	puzzle.guard_route_indices.resize(definition.guard_count)
	for guard_index: int in range(definition.guard_count):
		puzzle.guard_route_indices[guard_index] = floori(
			float(route_offsets.size() * guard_index) / float(definition.guard_count)
		)

	var visual: GhostStealthPuzzleVisual = GhostStealthPuzzleVisual.new()
	visual.name = "GhostStealthPuzzle%d" % puzzle.puzzle_index
	visual.z_index = 2
	add_child(visual)
	visual.global_position = world_map.navigation_tile_to_world(plan.center_tile)
	visual.configure(definition, route_offsets, puzzle.guard_route_indices)
	puzzle.visual = visual
	_puzzles.append(puzzle)


func _build_route(waypoints: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if waypoints.size() < 2:
		return result
	for waypoint_index: int in range(waypoints.size()):
		var current: Vector2i = waypoints[waypoint_index]
		var target: Vector2i = waypoints[(waypoint_index + 1) % waypoints.size()]
		if result.is_empty() or result[result.size() - 1] != current:
			result.append(current)
		while current != target:
			var delta: Vector2i = target - current
			if delta.x != 0:
				current.x += signi(delta.x)
			elif delta.y != 0:
				current.y += signi(delta.y)
			if current != waypoints[0] or waypoint_index < waypoints.size() - 1:
				result.append(current)
	return result


func _is_tile_seen(puzzle: GhostStealthPuzzleInstance, tile: Vector2i) -> bool:
	for guard_index: int in range(puzzle.guard_route_indices.size()):
		var guard_tile: Vector2i = puzzle.get_guard_tile(guard_index)
		var facing: Vector2i = puzzle.get_guard_facing(guard_index)
		for vision_offset: Vector2i in puzzle.definition.get_vision_offsets(facing):
			if guard_tile + vision_offset == tile:
				return true
	return false


func _has_player_nearby(puzzle: GhostStealthPuzzleInstance) -> bool:
	var radius_squared: float = pow(float(puzzle.definition.reset_radius_tiles), 2.0)
	for candidate: Node in get_tree().get_nodes_in_group("player"):
		var player: Survi2Player = candidate as Survi2Player
		if player == null:
			continue
		var tile: Vector2i = world_map.world_to_navigation_tile(player.global_position)
		if Vector2(tile).distance_squared_to(Vector2(puzzle.plan.center_tile)) \
				<= radius_squared:
			return true
	return false


func _announce_if_nearby(
		puzzle: GhostStealthPuzzleInstance,
		peer_id: int,
		player_tile: Vector2i
	) -> void:
	if puzzle.announced_peers.has(peer_id):
		return
	var distance: float = Vector2(player_tile).distance_to(
		Vector2(puzzle.plan.center_tile)
	)
	if distance > float(puzzle.definition.discovery_radius_tiles):
		return
	puzzle.announced_peers[peer_id] = true
	request_peer_message(
		peer_id,
		puzzle.definition.display_name,
		puzzle.definition.instructions,
		"Lila Felder zeigen die Ghost-Sensoren",
		"Nutze Sensorbedingungen und berühre unbemerkt den Schatz.",
		MessageTone.INFO,
		9.0
	)


func _fail_attempt(puzzle: GhostStealthPuzzleInstance, peer_id: int) -> void:
	puzzle.treasure_visible = false
	_set_puzzle_state.rpc(
		puzzle.puzzle_index,
		puzzle.guard_route_indices,
		false,
		false
	)
	_notify_detection_to_nearby_players(puzzle, peer_id)


func _notify_detection_to_nearby_players(
		puzzle: GhostStealthPuzzleInstance,
		caught_peer_id: int
	) -> void:
	var notified_peers: Dictionary[int, bool] = {}
	var radius_squared: float = pow(float(puzzle.definition.reset_radius_tiles), 2.0)
	for candidate: Node in get_tree().get_nodes_in_group("player"):
		var player: Survi2Player = candidate as Survi2Player
		if player == null:
			continue
		var tile: Vector2i = world_map.world_to_navigation_tile(player.global_position)
		if Vector2(tile).distance_squared_to(Vector2(puzzle.plan.center_tile)) \
				> radius_squared:
			continue
		var target_peer_id: int = player.get_multiplayer_authority()
		if notified_peers.has(target_peer_id):
			continue
		notified_peers[target_peer_id] = true
		var message: String = "Ein Ghost hat dich gesehen. Der Schatz ist verschwunden." \
			if target_peer_id == caught_peer_id \
			else "Ein Ghost hat einen Spieler gesehen. Der Schatz ist verschwunden."
		request_peer_message(
			target_peer_id,
			puzzle.definition.display_name,
			message,
			"Entdeckt!",
			"Verlasst alle den Bereich; erst dann erscheint der Schatz erneut.",
			MessageTone.FAILURE,
			7.0
		)


func _complete_puzzle(
		puzzle: GhostStealthPuzzleInstance,
		peer_id: int
	) -> void:
	puzzle.completed = true
	puzzle.treasure_visible = false
	_set_puzzle_state.rpc(
		puzzle.puzzle_index,
		puzzle.guard_route_indices,
		false,
		true
	)
	_spawn_rewards(puzzle)
	request_peer_message(
		peer_id,
		puzzle.definition.display_name,
		"Du hast das Patrouillenmuster richtig gelesen und den Schatz erreicht.",
		"Geisterhort gelöst!",
		"Die seltene Sumpfbeute wurde freigegeben.",
		MessageTone.SUCCESS,
		8.0
	)


func _spawn_rewards(puzzle: GhostStealthPuzzleInstance) -> void:
	var spawner: WorldEntitySpawner = WorldEntitySpawner.get_for(self)
	if not is_instance_valid(spawner):
		push_warning("GhostStealthPuzzleHandler: WorldEntitySpawner is missing")
		return
	var reward_position: Vector2 = world_map.navigation_tile_to_world(
		puzzle.treasure_tile
	)
	for item_value: Variant in puzzle.definition.rewards.keys():
		var item_id: String = String(item_value)
		var amount: int = int(puzzle.definition.rewards[item_value])
		if amount > 0 and Items.item_definitions.has(item_id):
			spawner.spawn_pickups(item_id, reward_position, amount)


func _get_puzzle(index: int) -> GhostStealthPuzzleInstance:
	if index < 0 or index >= _puzzles.size():
		return null
	return _puzzles[index]


@rpc("authority", "call_local", "reliable")
func _set_puzzle_state(
		puzzle_index: int,
		guard_indices: PackedInt32Array,
		treasure_is_visible: bool,
		is_completed: bool
	) -> void:
	var puzzle: GhostStealthPuzzleInstance = _get_puzzle(puzzle_index)
	if puzzle == null:
		return
	puzzle.guard_route_indices = guard_indices.duplicate()
	puzzle.treasure_visible = treasure_is_visible
	puzzle.completed = is_completed
	if is_instance_valid(puzzle.visual):
		puzzle.visual.set_state(
			guard_indices,
			treasure_is_visible,
			is_completed
		)


@rpc("authority", "call_local", "reliable")
func _sync_puzzle_snapshot(peer_id: int, snapshot: Array[Dictionary]) -> void:
	if multiplayer.get_unique_id() != peer_id:
		return
	for puzzle_index: int in range(mini(snapshot.size(), _puzzles.size())):
		var state: Dictionary = snapshot[puzzle_index]
		var indices: PackedInt32Array = PackedInt32Array(state.get(
			"guard_indices", PackedInt32Array()
		))
		_set_puzzle_state(
			puzzle_index,
			indices,
			bool(state.get("treasure_visible", true)),
			bool(state.get("completed", false))
		)
