extends ProgramPuzzleHandler
class_name SequencePuzzleHandler

@export var definitions: Array[SequencePuzzleDefinition] = []

var _definitions_by_landmark: Dictionary[StringName, SequencePuzzleDefinition] = {}
var _puzzles: Array[SequencePuzzleInstance] = []


func _ready() -> void:
	_rebuild_definition_index()


func server_tick(delta: float) -> void:
	_update_active_timers(delta)


func load_landmarks(plans: Array[LandmarkPlan]) -> void:
	_rebuild_definition_index()
	if not is_instance_valid(world_map):
		return
	for plan: LandmarkPlan in plans:
		var definition: SequencePuzzleDefinition = _definitions_by_landmark.get(
			plan.landmark_id
		) as SequencePuzzleDefinition
		if definition == null:
			continue
		_create_puzzle(definition, plan)


func clear_handler() -> void:
	for puzzle: SequencePuzzleInstance in _puzzles:
		for visual: ProgramPuzzleSwitch in puzzle.switch_visuals:
			if is_instance_valid(visual):
				visual.queue_free()
	_puzzles.clear()


func _rebuild_definition_index() -> void:
	_definitions_by_landmark.clear()
	for definition: SequencePuzzleDefinition in definitions:
		if definition != null and definition.is_valid():
			_definitions_by_landmark[definition.landmark_id] = definition


func _create_puzzle(
		definition: SequencePuzzleDefinition,
		plan: LandmarkPlan
	) -> void:
	var puzzle: SequencePuzzleInstance = SequencePuzzleInstance.new(
		_puzzles.size(), definition, plan
	)
	var numbers: Array[int] = []
	for number: int in range(1, definition.switch_offsets.size() + 1):
		numbers.append(number)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = Multihelper.mapSeed \
		^ plan.center_tile.x * 73856093 \
		^ plan.center_tile.y * 19349663 \
		^ puzzle.puzzle_index * 83492791
	_shuffle_numbers(numbers, rng)
	for index: int in range(definition.switch_offsets.size()):
		var tile: Vector2i = plan.center_tile + definition.switch_offsets[index]
		puzzle.switch_tiles.append(tile)
		puzzle.switch_numbers.append(numbers[index])
		var visual: ProgramPuzzleSwitch = ProgramPuzzleSwitch.new()
		visual.name = "Puzzle%dSwitch%d" % [puzzle.puzzle_index, index]
		add_child(visual)
		visual.global_position = world_map.navigation_tile_to_world(tile)
		visual.configure(numbers[index])
		puzzle.switch_visuals.append(visual)
	_puzzles.append(puzzle)


func _shuffle_numbers(numbers: Array[int], rng: RandomNumberGenerator) -> void:
	for index: int in range(numbers.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var temporary: int = numbers[index]
		numbers[index] = numbers[swap_index]
		numbers[swap_index] = temporary


func _update_active_timers(delta: float) -> void:
	for puzzle: SequencePuzzleInstance in _puzzles:
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
		_try_activate_switch(player, peer_id, tile)


func sync_peer(peer_id: int) -> void:
	var snapshot: Array[Dictionary] = []
	for puzzle: SequencePuzzleInstance in _puzzles:
		snapshot.append({
			"completed": puzzle.completed,
			"next_number": puzzle.next_number if puzzle.active_peer_id >= 0 else 1,
		})
	_sync_puzzle_snapshot.rpc(peer_id, snapshot)


func _announce_nearby_puzzles(peer_id: int, player_tile: Vector2i) -> void:
	for puzzle: SequencePuzzleInstance in _puzzles:
		if puzzle.completed or puzzle.announced_peers.has(peer_id):
			continue
		var distance: float = Vector2(player_tile).distance_to(
			Vector2(puzzle.plan.center_tile)
		)
		if distance > float(puzzle.definition.discovery_radius_tiles):
			continue
		puzzle.announced_peers[peer_id] = true
		_notify_hint(puzzle, peer_id)


func _try_activate_switch(
		_player: Survi2Player,
		peer_id: int,
		tile: Vector2i
	) -> void:
	for puzzle: SequencePuzzleInstance in _puzzles:
		if puzzle.completed:
			continue
		var switch_index: int = puzzle.get_switch_index(tile)
		if switch_index < 0:
			continue
		_handle_switch_touch(puzzle, switch_index, peer_id)
		return


func _handle_switch_touch(
		puzzle: SequencePuzzleInstance,
		switch_index: int,
		peer_id: int
	) -> void:
	var touched_number: int = puzzle.switch_numbers[switch_index]
	if puzzle.active_peer_id >= 0 and puzzle.active_peer_id != peer_id:
		_notify_notice(
			puzzle,
			peer_id,
			"Dieses Rätsel wird gerade von einem anderen Spieler gelöst."
		)
		return
	if puzzle.active_peer_id < 0:
		if touched_number != 1:
			_show_switch_feedback.rpc(puzzle.puzzle_index, switch_index, false)
			_notify_result(
				puzzle,
				peer_id,
				"Das war Schalter %d. Beginne die Sequenz bei 1." % touched_number,
				false
			)
			return
		puzzle.active_peer_id = peer_id
		puzzle.next_number = 1
		puzzle.time_remaining = puzzle.definition.time_limit_seconds
	if touched_number != puzzle.next_number:
		_show_switch_feedback.rpc(puzzle.puzzle_index, switch_index, false)
		_fail_puzzle(
			puzzle,
			"Falsche Reihenfolge: Schalter %d statt %d." % [
				touched_number,
				puzzle.next_number,
			]
		)
		return
	_show_switch_feedback.rpc(puzzle.puzzle_index, switch_index, true)
	puzzle.next_number += 1
	if puzzle.next_number > puzzle.switch_tiles.size():
		_complete_puzzle(puzzle)
		return
	_notify_progress(puzzle, peer_id, ceili(puzzle.time_remaining))


func _fail_puzzle(puzzle: SequencePuzzleInstance, message: String) -> void:
	var peer_id: int = puzzle.active_peer_id
	_schedule_visual_reset.rpc(puzzle.puzzle_index, 1.2)
	puzzle.reset_progress()
	if peer_id >= 0:
		_notify_result(puzzle, peer_id, message, false)


func _complete_puzzle(puzzle: SequencePuzzleInstance) -> void:
	var peer_id: int = puzzle.active_peer_id
	puzzle.completed = true
	puzzle.active_peer_id = -1
	_mark_puzzle_completed.rpc(puzzle.puzzle_index)
	_spawn_rewards(puzzle)
	_notify_result(
		puzzle,
		peer_id,
		"Sequenz vollständig. Die Tempelbelohnung wurde freigegeben!",
		true
	)


func _spawn_rewards(puzzle: SequencePuzzleInstance) -> void:
	var spawner: WorldEntitySpawner = WorldEntitySpawner.get_for(self)
	if not is_instance_valid(spawner):
		push_warning("SequencePuzzleHandler: WorldEntitySpawner is missing")
		return
	var reward_tile: Vector2i = puzzle.plan.center_tile + puzzle.definition.reward_offset
	var reward_position: Vector2 = world_map.navigation_tile_to_world(reward_tile)
	for item_value: Variant in puzzle.definition.rewards.keys():
		var item_id: String = String(item_value)
		var amount: int = int(puzzle.definition.rewards[item_value])
		if amount > 0 and Items.item_definitions.has(item_id):
			spawner.spawn_pickups(item_id, reward_position, amount)


func _get_puzzle(index: int) -> SequencePuzzleInstance:
	if index < 0 or index >= _puzzles.size():
		return null
	return _puzzles[index]


func _notify_hint(puzzle: SequencePuzzleInstance, peer_id: int) -> void:
	request_peer_message(
		peer_id,
		puzzle.definition.display_name,
		puzzle.definition.instructions,
		"Schalter finden: 1 → 2 → 3 → 4",
		"Die Zeit startet bei Schalter 1.",
		MessageTone.INFO,
		7.0
	)


func _notify_progress(
		puzzle: SequencePuzzleInstance,
		peer_id: int,
		seconds: int
	) -> void:
	request_peer_message(
		peer_id,
		puzzle.definition.display_name,
		"Programm läuft: Betrete den nächsten Schalter.",
		"Fortschritt: %d / %d" % [
			puzzle.next_number - 1,
			puzzle.switch_tiles.size(),
		],
		"Restzeit: %d s" % maxi(seconds, 0),
		MessageTone.ACTIVE
	)


func _notify_result(
		puzzle: SequencePuzzleInstance,
		peer_id: int,
		message: String,
		success: bool
	) -> void:
	request_peer_message(
		peer_id,
		puzzle.definition.display_name,
		message,
		"Rätsel gelöst!" if success else "Sequenz zurückgesetzt",
		"Belohnung wurde freigegeben." if success \
		else "Plane deinen Weg und versuche es erneut.",
		MessageTone.SUCCESS if success else MessageTone.FAILURE,
		5.0
	)


func _notify_notice(
		puzzle: SequencePuzzleInstance,
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
func _show_switch_feedback(
		puzzle_index: int,
		switch_index: int,
		is_correct: bool
	) -> void:
	var puzzle: SequencePuzzleInstance = _get_puzzle(puzzle_index)
	if puzzle == null or switch_index < 0 \
			or switch_index >= puzzle.switch_visuals.size():
		return
	var visual: ProgramPuzzleSwitch = puzzle.switch_visuals[switch_index]
	if is_instance_valid(visual):
		visual.reveal(is_correct)


@rpc("authority", "call_local", "reliable")
func _schedule_visual_reset(puzzle_index: int, delay_seconds: float) -> void:
	var puzzle: SequencePuzzleInstance = _get_puzzle(puzzle_index)
	if puzzle == null:
		return
	for visual: ProgramPuzzleSwitch in puzzle.switch_visuals:
		if is_instance_valid(visual):
			visual.reset_after(delay_seconds)


@rpc("authority", "call_local", "reliable")
func _mark_puzzle_completed(puzzle_index: int) -> void:
	var puzzle: SequencePuzzleInstance = _get_puzzle(puzzle_index)
	if puzzle == null:
		return
	puzzle.completed = true
	for visual: ProgramPuzzleSwitch in puzzle.switch_visuals:
		if is_instance_valid(visual):
			visual.mark_completed()


@rpc("authority", "call_local", "reliable")
func _sync_puzzle_snapshot(peer_id: int, snapshot: Array[Dictionary]) -> void:
	if multiplayer.get_unique_id() != peer_id:
		return
	for index: int in range(mini(snapshot.size(), _puzzles.size())):
		var puzzle: SequencePuzzleInstance = _puzzles[index]
		var state: Dictionary = snapshot[index]
		if bool(state.get("completed", false)):
			puzzle.completed = true
			for completed_visual: ProgramPuzzleSwitch in puzzle.switch_visuals:
				if is_instance_valid(completed_visual):
					completed_visual.mark_completed()
			continue
		var next_number: int = int(state.get("next_number", 1))
		for visual: ProgramPuzzleSwitch in puzzle.switch_visuals:
			if not is_instance_valid(visual):
				continue
			visual.reset_visual()
			if visual.switch_number < next_number:
				visual.reveal(true)


