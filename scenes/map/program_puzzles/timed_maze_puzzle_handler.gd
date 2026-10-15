extends ProgramPuzzleHandler
class_name TimedMazePuzzleHandler

@export var definitions: Array[TimedMazePuzzleDefinition] = []

var _definitions_by_landmark: Dictionary[StringName, TimedMazePuzzleDefinition] = {}
var _puzzles: Array[TimedMazePuzzleInstance] = []
var _generator: TimedMazeGenerator = TimedMazeGenerator.new()


func _ready() -> void:
	_rebuild_definition_index()


func server_tick(delta: float) -> void:
	_update_active_puzzles(delta)


func load_landmarks(plans: Array[LandmarkPlan]) -> void:
	_rebuild_definition_index()
	if not is_instance_valid(world_map):
		return
	for plan: LandmarkPlan in plans:
		var definition: TimedMazePuzzleDefinition = _definitions_by_landmark.get(
			plan.landmark_id
		) as TimedMazePuzzleDefinition
		if definition != null:
			_create_puzzle(definition, plan)


func clear_handler() -> void:
	for puzzle: TimedMazePuzzleInstance in _puzzles:
		if is_instance_valid(world_map) and not puzzle.wall_tiles.is_empty():
			world_map.remove_navigation_blockers(puzzle.wall_tiles)
		if is_instance_valid(puzzle.visual):
			puzzle.visual.queue_free()
	_puzzles.clear()


func _rebuild_definition_index() -> void:
	_definitions_by_landmark.clear()
	for definition: TimedMazePuzzleDefinition in definitions:
		if definition != null and definition.is_valid():
			_definitions_by_landmark[definition.landmark_id] = definition


func _create_puzzle(
		definition: TimedMazePuzzleDefinition,
		plan: LandmarkPlan
	) -> void:
	var generated: Dictionary = _generator.generate(
		plan.bounds,
		Multihelper.mapSeed \
			^ plan.center_tile.x * 73856093 \
			^ plan.center_tile.y * 19349663
	)
	var puzzle: TimedMazePuzzleInstance = TimedMazePuzzleInstance.new(
		_puzzles.size(), definition, plan
	)
	puzzle.wall_tiles.assign(generated.get("wall_tiles", []))
	puzzle.start_tile = generated.get("start_tile", plan.center_tile)
	puzzle.goal_tile = generated.get("goal_tile", plan.center_tile)
	world_map.add_navigation_blockers(puzzle.wall_tiles)

	var visual: TimedMazePuzzleVisual = TimedMazePuzzleVisual.new()
	visual.name = "TimedMazePuzzle%d" % puzzle.puzzle_index
	visual.z_index = -2
	add_child(visual)
	visual.global_position = world_map.navigation_tile_to_world(plan.bounds.position)
	visual.configure(
		plan.bounds.position,
		puzzle.wall_tiles,
		puzzle.start_tile,
		puzzle.goal_tile
	)
	puzzle.visual = visual
	_puzzles.append(puzzle)


func _update_active_puzzles(delta: float) -> void:
	for puzzle: TimedMazePuzzleInstance in _puzzles:
		if puzzle.completed or puzzle.active_peer_id < 0:
			continue
		puzzle.time_remaining = maxf(puzzle.time_remaining - delta, 0.0)
		var displayed_second: int = ceili(puzzle.time_remaining)
		if displayed_second != puzzle.last_displayed_second:
			puzzle.last_displayed_second = displayed_second
			_notify_progress(puzzle, puzzle.active_peer_id, displayed_second)
		if puzzle.time_remaining <= 0.0:
			_fail_puzzle(puzzle, "Die Zeit ist abgelaufen.")


func server_observe_player(
		player: Survi2Player,
		peer_id: int,
		tile: Vector2i,
		tile_changed: bool
	) -> void:
	_announce_nearby_puzzles(peer_id, tile)
	if tile_changed:
		_handle_tile_entered(player, peer_id, tile)


func _handle_tile_entered(
		player: Survi2Player,
		peer_id: int,
		tile: Vector2i
	) -> void:
	for puzzle: TimedMazePuzzleInstance in _puzzles:
		if puzzle.completed:
			continue
		if tile == puzzle.start_tile:
			_try_start_puzzle(puzzle, peer_id)
			return
		if tile == puzzle.goal_tile:
			_try_complete_puzzle(puzzle, player, peer_id)
			return


func _try_start_puzzle(puzzle: TimedMazePuzzleInstance, peer_id: int) -> void:
	if puzzle.active_peer_id >= 0:
		if puzzle.active_peer_id != peer_id:
			_notify_notice(
				puzzle,
				peer_id,
				"Dieses Labyrinth wird gerade von einem anderen Spieler gelöst."
			)
		return
	puzzle.active_peer_id = peer_id
	puzzle.time_remaining = puzzle.definition.time_limit_seconds
	puzzle.last_displayed_second = ceili(puzzle.time_remaining)
	_set_maze_active.rpc(puzzle.puzzle_index, true)
	_notify_progress(puzzle, peer_id, puzzle.last_displayed_second)


func _try_complete_puzzle(
		puzzle: TimedMazePuzzleInstance,
		_player: Survi2Player,
		peer_id: int
	) -> void:
	if puzzle.active_peer_id < 0:
		_notify_notice(puzzle, peer_id, "Berühre zuerst das weiße Startfeld.")
		return
	if puzzle.active_peer_id != peer_id:
		_notify_notice(
			puzzle,
			peer_id,
			"Ein anderer Spieler versucht dieses Labyrinth gerade."
		)
		return
	_complete_puzzle(puzzle)


func _fail_puzzle(puzzle: TimedMazePuzzleInstance, message: String) -> void:
	var peer_id: int = puzzle.active_peer_id
	var player: Survi2Player = _find_player(peer_id)
	puzzle.reset_attempt()
	_set_maze_active.rpc(puzzle.puzzle_index, false)
	if player != null:
		request_player_tile_memory(peer_id, puzzle.start_tile)
		player.teleport_from_server.rpc(
			world_map.navigation_tile_to_world(puzzle.start_tile)
		)
	if peer_id >= 0:
		_notify_result(
			puzzle,
			peer_id,
			message + " Du wurdest zum Start zurückgebracht.",
			false
		)


func _complete_puzzle(puzzle: TimedMazePuzzleInstance) -> void:
	var peer_id: int = puzzle.active_peer_id
	puzzle.completed = true
	puzzle.reset_attempt()
	_mark_puzzle_completed.rpc(puzzle.puzzle_index)
	_spawn_rewards(puzzle)
	_notify_result(
		puzzle,
		peer_id,
		"Ausgang rechtzeitig erreicht. Die Gebirgsbelohnung wurde freigegeben!",
		true
	)


func _spawn_rewards(puzzle: TimedMazePuzzleInstance) -> void:
	var spawner: WorldEntitySpawner = WorldEntitySpawner.get_for(self)
	if not is_instance_valid(spawner):
		push_warning("TimedMazePuzzleHandler: WorldEntitySpawner is missing")
		return
	var reward_position: Vector2 = world_map.navigation_tile_to_world(
		puzzle.goal_tile
	)
	for item_value: Variant in puzzle.definition.rewards.keys():
		var item_id: String = String(item_value)
		var amount: int = int(puzzle.definition.rewards[item_value])
		if amount > 0 and Items.item_definitions.has(item_id):
			spawner.spawn_pickups(item_id, reward_position, amount)


func _find_player(peer_id: int) -> Survi2Player:
	for candidate: Node in get_tree().get_nodes_in_group("player"):
		var player: Survi2Player = candidate as Survi2Player
		if player != null and player.get_multiplayer_authority() == peer_id:
			return player
	return null


func _announce_nearby_puzzles(peer_id: int, player_tile: Vector2i) -> void:
	for puzzle: TimedMazePuzzleInstance in _puzzles:
		if puzzle.completed or puzzle.announced_peers.has(peer_id):
			continue
		var distance: float = Vector2(player_tile).distance_to(
			Vector2(puzzle.plan.center_tile)
		)
		if distance > float(puzzle.definition.discovery_radius_tiles):
			continue
		puzzle.announced_peers[peer_id] = true
		_notify_hint(puzzle, peer_id)


func sync_peer(peer_id: int) -> void:
	var snapshot: Array[Dictionary] = []
	for puzzle: TimedMazePuzzleInstance in _puzzles:
		snapshot.append({
			"completed": puzzle.completed,
			"active": puzzle.active_peer_id >= 0,
		})
	_sync_puzzle_snapshot.rpc(peer_id, snapshot)


func _get_puzzle(index: int) -> TimedMazePuzzleInstance:
	if index < 0 or index >= _puzzles.size():
		return null
	return _puzzles[index]


func _notify_hint(puzzle: TimedMazePuzzleInstance, peer_id: int) -> void:
	request_peer_message(
		peer_id,
		puzzle.definition.display_name,
		puzzle.definition.instructions,
		"Start: weißes Feld  •  Ziel: schwarzes Feld",
		"Der Countdown startet erst beim Betreten des Startfelds.",
		MessageTone.INFO,
		8.0
	)


func _notify_progress(
		puzzle: TimedMazePuzzleInstance,
		peer_id: int,
		seconds: int
	) -> void:
	request_peer_message(
		peer_id,
		puzzle.definition.display_name,
		"Programm läuft: Finde das schwarze Zielfeld.",
		"Labyrinth aktiv",
		"Restzeit: %d s" % maxi(seconds, 0),
		MessageTone.ACTIVE
	)


func _notify_result(
		puzzle: TimedMazePuzzleInstance,
		peer_id: int,
		message: String,
		success: bool
	) -> void:
	request_peer_message(
		peer_id,
		puzzle.definition.display_name,
		message,
		"Labyrinth geschafft!" if success else "Versuch beendet",
		"Belohnung wurde freigegeben." if success \
		else "Plane einen neuen Weg und betrete das weiße Feld erneut.",
		MessageTone.SUCCESS if success else MessageTone.FAILURE,
		6.0
	)


func _notify_notice(
		puzzle: TimedMazePuzzleInstance,
		peer_id: int,
		message: String
	) -> void:
	request_peer_message(
		peer_id,
		puzzle.definition.display_name,
		message,
		"Gemeinsames Programmier-Rätsel",
		"Warte kurz oder hilf beim Planen.",
		MessageTone.INFO,
		4.0
	)


@rpc("authority", "call_local", "reliable")
func _set_maze_active(puzzle_index: int, active: bool) -> void:
	var puzzle: TimedMazePuzzleInstance = _get_puzzle(puzzle_index)
	if puzzle != null and is_instance_valid(puzzle.visual):
		puzzle.visual.set_start_active(active)


@rpc("authority", "call_local", "reliable")
func _mark_puzzle_completed(puzzle_index: int) -> void:
	var puzzle: TimedMazePuzzleInstance = _get_puzzle(puzzle_index)
	if puzzle == null:
		return
	puzzle.completed = true
	if is_instance_valid(puzzle.visual):
		puzzle.visual.mark_completed()


@rpc("authority", "call_local", "reliable")
func _sync_puzzle_snapshot(peer_id: int, snapshot: Array[Dictionary]) -> void:
	if multiplayer.get_unique_id() != peer_id:
		return
	for index: int in range(mini(snapshot.size(), _puzzles.size())):
		var puzzle: TimedMazePuzzleInstance = _puzzles[index]
		var state: Dictionary = snapshot[index]
		if bool(state.get("completed", false)):
			puzzle.completed = true
			if is_instance_valid(puzzle.visual):
				puzzle.visual.mark_completed()
		elif is_instance_valid(puzzle.visual):
			puzzle.visual.set_start_active(bool(state.get("active", false)))


