extends ProgramPuzzleHandler
class_name ItemOfferingPuzzleHandler

@export var definitions: Array[ItemOfferingPuzzleDefinition] = []

var _definitions_by_landmark: Dictionary[StringName, ItemOfferingPuzzleDefinition] = {}
var _puzzles: Array[ItemOfferingPuzzleInstance] = []
var _spawner: WorldEntitySpawner


func _ready() -> void:
	_rebuild_definition_index()
	call_deferred("_connect_spawner")


func load_landmarks(plans: Array[LandmarkPlan]) -> void:
	_rebuild_definition_index()
	_connect_spawner()
	if not is_instance_valid(world_map):
		return
	for plan: LandmarkPlan in plans:
		var definition: ItemOfferingPuzzleDefinition = _definitions_by_landmark.get(
			plan.landmark_id
		) as ItemOfferingPuzzleDefinition
		if definition != null:
			_create_puzzle(definition, plan)


func clear_handler() -> void:
	for puzzle: ItemOfferingPuzzleInstance in _puzzles:
		for pickup: WorldPickup in puzzle.accepted_pickups.values():
			if is_instance_valid(pickup):
				pickup.release_reservation()
		if is_instance_valid(puzzle.visual):
			puzzle.visual.queue_free()
	_puzzles.clear()


func server_observe_player(
		_player: Survi2Player,
		peer_id: int,
		tile: Vector2i,
		_tile_changed: bool
	) -> void:
	for puzzle: ItemOfferingPuzzleInstance in _puzzles:
		if puzzle.completed or puzzle.announced_peers.has(peer_id):
			continue
		var distance: float = Vector2(tile).distance_to(
			Vector2(puzzle.plan.center_tile)
		)
		if distance > float(puzzle.definition.discovery_radius_tiles):
			continue
		puzzle.announced_peers[peer_id] = true
		_show_hint(puzzle, peer_id)


func sync_peer(peer_id: int) -> void:
	var snapshot: Array[Dictionary] = []
	for puzzle: ItemOfferingPuzzleInstance in _puzzles:
		snapshot.append({
			"completed": puzzle.completed,
			"next_slot": puzzle.next_slot,
		})
	_sync_puzzle_snapshot.rpc(peer_id, snapshot)


func _rebuild_definition_index() -> void:
	_definitions_by_landmark.clear()
	for definition: ItemOfferingPuzzleDefinition in definitions:
		if definition != null and definition.is_valid():
			_definitions_by_landmark[definition.landmark_id] = definition


func _connect_spawner() -> void:
	if is_instance_valid(_spawner):
		return
	_spawner = WorldEntitySpawner.get_for(self)
	if is_instance_valid(_spawner) \
			and not _spawner.pickup_spawned.is_connected(_on_pickup_spawned):
		_spawner.pickup_spawned.connect(_on_pickup_spawned)


func _create_puzzle(
		definition: ItemOfferingPuzzleDefinition,
		plan: LandmarkPlan
	) -> void:
	var puzzle: ItemOfferingPuzzleInstance = ItemOfferingPuzzleInstance.new(
		_puzzles.size(), definition, plan
	)
	for offset: Vector2i in definition.offering_offsets:
		puzzle.offering_tiles.append(plan.center_tile + offset)
	var visual: ItemOfferingPuzzleVisual = ItemOfferingPuzzleVisual.new()
	visual.name = "ItemOfferingPuzzle%d" % puzzle.puzzle_index
	visual.z_index = -1
	add_child(visual)
	visual.global_position = world_map.navigation_tile_to_world(plan.center_tile)
	visual.configure(
		plan.center_tile,
		puzzle.offering_tiles,
		definition.required_items
	)
	puzzle.visual = visual
	_puzzles.append(puzzle)


func _on_pickup_spawned(pickup: WorldPickup) -> void:
	if not multiplayer.is_server() or not is_instance_valid(pickup):
		return
	var context: Dictionary = pickup.get_meta(&"spawn_context", {})
	if context.get("source", &"") != &"player_drop":
		return
	var peer_id: int = int(context.get("peer_id", -1))
	var tile: Vector2i = world_map.world_to_navigation_tile(pickup.global_position)
	for puzzle: ItemOfferingPuzzleInstance in _puzzles:
		if puzzle.completed:
			continue
		var slot_index: int = puzzle.get_offering_index(tile)
		if slot_index < 0:
			continue
		_handle_offering(puzzle, slot_index, pickup, peer_id)
		return


func _handle_offering(
		puzzle: ItemOfferingPuzzleInstance,
		slot_index: int,
		pickup: WorldPickup,
		peer_id: int
	) -> void:
	var expected_slot: int = puzzle.next_slot
	var expected_item: String = String(
		puzzle.definition.required_items[expected_slot]
	)
	if slot_index != expected_slot or pickup.itemId != expected_item:
		_flash_wrong.rpc(puzzle.puzzle_index, slot_index)
		request_peer_message(
			peer_id,
			puzzle.definition.display_name,
			"Erwartet wird zuerst %d: %s." % [expected_slot + 1, expected_item],
			"Dieser Drop zählt nicht",
			"Das Item bleibt liegen und kann wieder aufgenommen werden.",
			MessageTone.FAILURE,
			4.0
		)
		return
	if not pickup.try_reserve():
		return
	puzzle.accepted_pickups[slot_index] = pickup
	puzzle.next_slot += 1
	_mark_slot_accepted.rpc(puzzle.puzzle_index, slot_index)
	if puzzle.next_slot >= puzzle.definition.required_items.size():
		_complete_puzzle(puzzle, peer_id)
		return
	var next_item: String = String(
		puzzle.definition.required_items[puzzle.next_slot]
	)
	request_peer_message(
		peer_id,
		puzzle.definition.display_name,
		"%s wurde angenommen. Als Nächstes: %s." % [pickup.itemId, next_item],
		"Fortschritt: %d / %d" % [
			puzzle.next_slot,
			puzzle.definition.required_items.size(),
		],
		"Nutze den Drop-Befehl am passenden Feld.",
		MessageTone.ACTIVE,
		4.0
	)


func _complete_puzzle(
		puzzle: ItemOfferingPuzzleInstance,
		peer_id: int
	) -> void:
	puzzle.completed = true
	for pickup: WorldPickup in puzzle.accepted_pickups.values():
		if is_instance_valid(pickup):
			pickup.consume_reserved()
	_mark_puzzle_completed.rpc(puzzle.puzzle_index)
	_spawn_rewards(puzzle)
	request_peer_message(
		peer_id,
		puzzle.definition.display_name,
		"stone, wood, iron und food wurden in der richtigen Reihenfolge geopfert.",
		"Friedhofsrätsel gelöst!",
		"Die Belohnung liegt am Altar bereit.",
		MessageTone.SUCCESS,
		7.0
	)


func _spawn_rewards(puzzle: ItemOfferingPuzzleInstance) -> void:
	if not is_instance_valid(_spawner):
		return
	var reward_tile: Vector2i = puzzle.plan.center_tile \
		+ puzzle.definition.reward_offset
	var reward_position: Vector2 = world_map.navigation_tile_to_world(reward_tile)
	for item_value: Variant in puzzle.definition.rewards.keys():
		var item_id: String = String(item_value)
		var amount: int = int(puzzle.definition.rewards[item_value])
		if amount > 0 and Items.item_definitions.has(item_id):
			_spawner.spawn_pickups(item_id, reward_position, amount)


func _show_hint(puzzle: ItemOfferingPuzzleInstance, peer_id: int) -> void:
	request_peer_message(
		peer_id,
		puzzle.definition.display_name,
		puzzle.definition.instructions,
		"Reihenfolge: 1 stone → 2 wood → 3 iron → 4 food",
		"Droppe jedes Item auf sein beschriftetes Feld.",
		MessageTone.INFO,
		9.0
	)


func _get_puzzle(index: int) -> ItemOfferingPuzzleInstance:
	if index < 0 or index >= _puzzles.size():
		return null
	return _puzzles[index]


@rpc("authority", "call_local", "reliable")
func _mark_slot_accepted(puzzle_index: int, slot_index: int) -> void:
	var puzzle: ItemOfferingPuzzleInstance = _get_puzzle(puzzle_index)
	if puzzle != null and is_instance_valid(puzzle.visual):
		puzzle.visual.mark_accepted(slot_index)


@rpc("authority", "call_local", "reliable")
func _flash_wrong(puzzle_index: int, slot_index: int) -> void:
	var puzzle: ItemOfferingPuzzleInstance = _get_puzzle(puzzle_index)
	if puzzle != null and is_instance_valid(puzzle.visual):
		puzzle.visual.flash_wrong(slot_index)


@rpc("authority", "call_local", "reliable")
func _mark_puzzle_completed(puzzle_index: int) -> void:
	var puzzle: ItemOfferingPuzzleInstance = _get_puzzle(puzzle_index)
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
		var puzzle: ItemOfferingPuzzleInstance = _puzzles[index]
		var state: Dictionary = snapshot[index]
		var next_slot: int = int(state.get("next_slot", 0))
		for slot_index: int in range(next_slot):
			if is_instance_valid(puzzle.visual):
				puzzle.visual.mark_accepted(slot_index)
		if bool(state.get("completed", false)):
			puzzle.completed = true
			if is_instance_valid(puzzle.visual):
				puzzle.visual.mark_completed()
