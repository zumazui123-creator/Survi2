extends ProgramPuzzleHandler
class_name BridgeRepairPuzzleHandler

@export var definitions: Array[BridgeRepairPuzzleDefinition] = []

var _definitions_by_landmark: Dictionary[StringName, BridgeRepairPuzzleDefinition] = {}
var _puzzles: Array[BridgeRepairPuzzleInstance] = []
var _building_manager: BuildingManager


func _ready() -> void:
	_rebuild_definition_index()
	_connect_building_manager()


func load_landmarks(plans: Array[LandmarkPlan]) -> void:
	_rebuild_definition_index()
	_connect_building_manager()
	if not is_instance_valid(world_map) or not is_instance_valid(_building_manager):
		return
	for plan: LandmarkPlan in plans:
		var definition: BridgeRepairPuzzleDefinition = _definitions_by_landmark.get(
			plan.landmark_id
		) as BridgeRepairPuzzleDefinition
		if definition != null and plan.bridge_tiles.size() >= 2:
			_create_puzzle(definition, plan)


func clear_handler() -> void:
	for puzzle: BridgeRepairPuzzleInstance in _puzzles:
		if is_instance_valid(_building_manager):
			_building_manager.unregister_terrain_build_sites(puzzle.source_id)
		if is_instance_valid(puzzle.visual):
			puzzle.visual.queue_free()
	_puzzles.clear()


func server_observe_player(
		_player: Survi2Player,
		peer_id: int,
		tile: Vector2i,
		_tile_changed: bool
	) -> void:
	for puzzle: BridgeRepairPuzzleInstance in _puzzles:
		_announce_if_nearby(puzzle, peer_id, tile)
		if puzzle.bridge_repaired and not puzzle.treasure_claimed \
				and tile == puzzle.treasure_tile:
			_claim_treasure(puzzle, peer_id)


func sync_peer(peer_id: int) -> void:
	var snapshot: Array[Dictionary] = []
	for puzzle: BridgeRepairPuzzleInstance in _puzzles:
		var repaired: Array[Vector2i] = []
		for tile: Vector2i in puzzle.repaired_tiles:
			repaired.append(tile)
		snapshot.append({
			"repaired_tiles": repaired,
			"bridge_repaired": puzzle.bridge_repaired,
			"treasure_claimed": puzzle.treasure_claimed,
		})
	_sync_puzzle_snapshot.rpc(peer_id, snapshot)


func _rebuild_definition_index() -> void:
	_definitions_by_landmark.clear()
	for definition: BridgeRepairPuzzleDefinition in definitions:
		if definition != null and definition.is_valid():
			_definitions_by_landmark[definition.landmark_id] = definition


func _connect_building_manager() -> void:
	if not is_instance_valid(_building_manager):
		_building_manager = get_tree().get_first_node_in_group(
			"building_manager"
		) as BuildingManager
	if is_instance_valid(_building_manager) \
			and not _building_manager.building_placed.is_connected(
				_on_building_placed
			):
		_building_manager.building_placed.connect(_on_building_placed)


func _create_puzzle(
		definition: BridgeRepairPuzzleDefinition,
		plan: LandmarkPlan
	) -> void:
	var puzzle: BridgeRepairPuzzleInstance = BridgeRepairPuzzleInstance.new(
		_puzzles.size(), definition, plan
	)
	puzzle.bridge_tiles.assign(plan.bridge_tiles)
	var direction: Vector2i = plan.bridge_tiles[1] - plan.bridge_tiles[0]
	var gap_count: int = mini(definition.gap_tile_count, plan.bridge_tiles.size())
	var gap_start: int = floori(float(plan.bridge_tiles.size() - gap_count) * 0.5)
	for tile_index: int in range(plan.bridge_tiles.size()):
		var tile: Vector2i = plan.bridge_tiles[tile_index]
		if tile_index >= gap_start and tile_index < gap_start + gap_count:
			puzzle.gap_tiles.append(tile)
			_building_manager.register_terrain_build_site(
				tile,
				definition.required_building_id,
				puzzle.source_id
			)
			world_map.set_navigation_terrain_tile(tile, false)
		else:
			_make_bridge_tile_walkable(tile)
	puzzle.treasure_tile = plan.bridge_tiles[plan.bridge_tiles.size() - 1] + direction

	var visual: BridgeRepairPuzzleVisual = BridgeRepairPuzzleVisual.new()
	visual.name = "BridgeRepairPuzzle%d" % puzzle.puzzle_index
	visual.z_index = 1
	add_child(visual)
	visual.global_position = world_map.navigation_tile_to_world(plan.center_tile)
	visual.configure(
		plan.center_tile,
		puzzle.bridge_tiles,
		puzzle.gap_tiles,
		puzzle.treasure_tile
	)
	puzzle.visual = visual
	_puzzles.append(puzzle)


func _on_building_placed(tile: Vector2i, building: BuildingEntity) -> void:
	if not multiplayer.is_server() or not is_instance_valid(building):
		return
	for puzzle: BridgeRepairPuzzleInstance in _puzzles:
		if puzzle.bridge_repaired or not puzzle.is_gap_tile(tile) \
				or puzzle.is_repaired(tile):
			continue
		if building.building_id != puzzle.definition.required_building_id:
			continue
		puzzle.repaired_tiles[tile] = true
		_building_manager.unregister_terrain_build_site(tile, puzzle.source_id)
		call_deferred(
			"_finish_wall_repair",
			puzzle.puzzle_index,
			tile,
			building,
			building.builder_peer_id
		)
		return


func _finish_wall_repair(
		puzzle_index: int,
		tile: Vector2i,
		building: BuildingEntity,
		builder_peer_id: int
	) -> void:
	var puzzle: BridgeRepairPuzzleInstance = _get_puzzle(puzzle_index)
	if puzzle == null:
		return
	if is_instance_valid(building):
		_building_manager.remove_building_immediately(building)
	_mark_tile_repaired.rpc(puzzle_index, tile)
	var repaired_count: int = puzzle.get_repaired_count()
	if repaired_count >= puzzle.gap_tiles.size():
		puzzle.bridge_repaired = true
		_set_puzzle_state.rpc(puzzle_index, true, false)
		request_peer_message(
			builder_peer_id,
			puzzle.definition.display_name,
			"Alle Lücken sind geschlossen. Am anderen Ufer ist ein Schatz erschienen.",
			"Brücke repariert!",
			"Überquere die Brücke und berühre den Schatz.",
			MessageTone.SUCCESS,
			8.0
		)
		return
	request_peer_message(
		builder_peer_id,
		puzzle.definition.display_name,
		"Die Mauer wurde als stabiles Brückensegment eingesetzt.",
		"Fortschritt: %d / %d" % [repaired_count, puzzle.gap_tiles.size()],
		"Baue auf der nächsten markierten Lücke weiter.",
		MessageTone.ACTIVE,
		5.0
	)


func _make_bridge_tile_walkable(tile: Vector2i) -> void:
	world_map.set_biome_path_field(tile)
	world_map.set_navigation_terrain_tile(tile, true)


func _announce_if_nearby(
		puzzle: BridgeRepairPuzzleInstance,
		peer_id: int,
		player_tile: Vector2i
	) -> void:
	if puzzle.treasure_claimed or puzzle.announced_peers.has(peer_id):
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
		"Lücken: %d  •  Material: Mauer" % puzzle.gap_tiles.size(),
		"Baue jede Mauer direkt auf ein orange markiertes Wasser-Tile.",
		MessageTone.INFO,
		9.0
	)


func _claim_treasure(
		puzzle: BridgeRepairPuzzleInstance,
		peer_id: int
	) -> void:
	puzzle.treasure_claimed = true
	_set_puzzle_state.rpc(puzzle.puzzle_index, true, true)
	_spawn_rewards(puzzle)
	request_peer_message(
		peer_id,
		puzzle.definition.display_name,
		"Du hast die reparierte Brücke überquert und den Schatz erreicht.",
		"Brückenrätsel gelöst!",
		"Die Belohnung liegt am anderen Ufer bereit.",
		MessageTone.SUCCESS,
		8.0
	)


func _spawn_rewards(puzzle: BridgeRepairPuzzleInstance) -> void:
	var spawner: WorldEntitySpawner = WorldEntitySpawner.get_for(self)
	if not is_instance_valid(spawner):
		push_warning("BridgeRepairPuzzleHandler: WorldEntitySpawner is missing")
		return
	var reward_position: Vector2 = world_map.navigation_tile_to_world(
		puzzle.treasure_tile
	)
	for item_value: Variant in puzzle.definition.rewards.keys():
		var item_id: String = String(item_value)
		var amount: int = int(puzzle.definition.rewards[item_value])
		if amount > 0 and Items.item_definitions.has(item_id):
			spawner.spawn_pickups(item_id, reward_position, amount)


func _get_puzzle(index: int) -> BridgeRepairPuzzleInstance:
	if index < 0 or index >= _puzzles.size():
		return null
	return _puzzles[index]


@rpc("authority", "call_local", "reliable")
func _mark_tile_repaired(puzzle_index: int, tile: Vector2i) -> void:
	var puzzle: BridgeRepairPuzzleInstance = _get_puzzle(puzzle_index)
	if puzzle == null:
		return
	puzzle.repaired_tiles[tile] = true
	if is_instance_valid(_building_manager):
		_building_manager.unregister_terrain_build_site(tile, puzzle.source_id)
	_make_bridge_tile_walkable(tile)
	if is_instance_valid(puzzle.visual):
		puzzle.visual.mark_repaired(tile - puzzle.plan.center_tile)


@rpc("authority", "call_local", "reliable")
func _set_puzzle_state(
		puzzle_index: int,
		is_bridge_repaired: bool,
		is_treasure_claimed: bool
	) -> void:
	var puzzle: BridgeRepairPuzzleInstance = _get_puzzle(puzzle_index)
	if puzzle == null:
		return
	puzzle.bridge_repaired = is_bridge_repaired
	puzzle.treasure_claimed = is_treasure_claimed
	if is_instance_valid(puzzle.visual):
		puzzle.visual.set_state(is_bridge_repaired, is_treasure_claimed)


@rpc("authority", "call_local", "reliable")
func _sync_puzzle_snapshot(peer_id: int, snapshot: Array[Dictionary]) -> void:
	if multiplayer.get_unique_id() != peer_id:
		return
	for puzzle_index: int in range(mini(snapshot.size(), _puzzles.size())):
		var state: Dictionary = snapshot[puzzle_index]
		var repaired_tiles: Array[Vector2i] = []
		repaired_tiles.assign(state.get("repaired_tiles", []))
		for tile: Vector2i in repaired_tiles:
			_mark_tile_repaired(puzzle_index, tile)
		_set_puzzle_state(
			puzzle_index,
			bool(state.get("bridge_repaired", false)),
			bool(state.get("treasure_claimed", false))
		)
