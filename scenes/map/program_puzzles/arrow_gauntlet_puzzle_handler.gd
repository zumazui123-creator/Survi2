extends ProgramPuzzleHandler
class_name ArrowGauntletPuzzleHandler

const ARROW_SCENE: PackedScene = preload(
	"res://scenes/map/program_puzzles/arrow_gauntlet_projectile.tscn"
)

@export var definitions: Array[ArrowGauntletPuzzleDefinition] = []

var _definitions_by_landmark: Dictionary[StringName, ArrowGauntletPuzzleDefinition] = {}
var _puzzles: Array[ArrowGauntletPuzzleInstance] = []


func _ready() -> void:
	_rebuild_definition_index()


func load_landmarks(plans: Array[LandmarkPlan]) -> void:
	_rebuild_definition_index()
	if not is_instance_valid(world_map):
		return
	for plan: LandmarkPlan in plans:
		var definition: ArrowGauntletPuzzleDefinition = _definitions_by_landmark.get(
			plan.landmark_id
		) as ArrowGauntletPuzzleDefinition
		if definition != null:
			_create_puzzle(definition, plan)


func clear_handler() -> void:
	for puzzle: ArrowGauntletPuzzleInstance in _puzzles:
		if is_instance_valid(world_map) and not puzzle.barrier_tiles.is_empty():
			world_map.remove_navigation_blockers(puzzle.barrier_tiles)
		if is_instance_valid(puzzle.visual):
			puzzle.visual.queue_free()
	_puzzles.clear()


func server_tick(delta: float) -> void:
	for puzzle: ArrowGauntletPuzzleInstance in _puzzles:
		if puzzle.treasure_claimed or not _has_player_near(puzzle):
			puzzle.volley_remaining = puzzle.definition.volley_interval_seconds
			continue
		puzzle.volley_remaining -= delta
		if puzzle.volley_remaining > 0.0:
			continue
		puzzle.volley_remaining = puzzle.definition.volley_interval_seconds
		_fire_volley(puzzle)


func server_observe_player(
		_player: Survi2Player,
		peer_id: int,
		tile: Vector2i,
		_tile_changed: bool
	) -> void:
	for puzzle: ArrowGauntletPuzzleInstance in _puzzles:
		_announce_if_nearby(puzzle, peer_id, tile)
		if not puzzle.treasure_claimed and tile == puzzle.treasure_tile:
			_claim_treasure(puzzle, peer_id)


func sync_peer(peer_id: int) -> void:
	var snapshot: Array[bool] = []
	for puzzle: ArrowGauntletPuzzleInstance in _puzzles:
		snapshot.append(puzzle.treasure_claimed)
	_sync_puzzle_snapshot.rpc(peer_id, snapshot)


func _rebuild_definition_index() -> void:
	_definitions_by_landmark.clear()
	for definition: ArrowGauntletPuzzleDefinition in definitions:
		if definition != null and definition.is_valid():
			_definitions_by_landmark[definition.landmark_id] = definition


func _create_puzzle(
		definition: ArrowGauntletPuzzleDefinition,
		plan: LandmarkPlan
	) -> void:
	var puzzle: ArrowGauntletPuzzleInstance = ArrowGauntletPuzzleInstance.new(
		_puzzles.size(), definition, plan
	)
	puzzle.barrier_tiles = _create_barrier_tiles(plan.center_tile, definition)
	world_map.add_navigation_blockers(puzzle.barrier_tiles)

	var visual: ArrowGauntletPuzzleVisual = ArrowGauntletPuzzleVisual.new()
	visual.name = "ArrowGauntletPuzzle%d" % puzzle.puzzle_index
	visual.z_index = -1
	add_child(visual)
	visual.global_position = world_map.navigation_tile_to_world(plan.center_tile)
	visual.configure(definition)
	puzzle.visual = visual
	_puzzles.append(puzzle)


func _create_barrier_tiles(
		center: Vector2i,
		definition: ArrowGauntletPuzzleDefinition
	) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y_offset: int in range(-definition.barrier_half_height, definition.barrier_half_height + 1):
		result.append(center + Vector2i(-definition.barrier_x_offset, y_offset))
		result.append(center + Vector2i(definition.barrier_x_offset, y_offset))
	for x_offset: int in range(-definition.barrier_x_offset + 1, definition.barrier_x_offset):
		result.append(center + Vector2i(x_offset, -definition.barrier_half_height))
		if x_offset != definition.start_offset.x:
			result.append(center + Vector2i(x_offset, definition.barrier_half_height))
	return result


func _has_player_near(puzzle: ArrowGauntletPuzzleInstance) -> bool:
	for candidate: Node in get_tree().get_nodes_in_group(&"player"):
		var player: Survi2Player = candidate as Survi2Player
		if player == null:
			continue
		var tile: Vector2i = world_map.world_to_navigation_tile(player.global_position)
		if puzzle.is_player_near(tile):
			return true
	return false


func _fire_volley(puzzle: ArrowGauntletPuzzleInstance) -> void:
	var spawner: WorldEntitySpawner = WorldEntitySpawner.get_for(self)
	if not is_instance_valid(spawner) or not is_instance_valid(spawner.projectiles_root):
		return
	for row_index: int in range(puzzle.definition.hazard_row_offsets.size()):
		var row: int = puzzle.definition.hazard_row_offsets[row_index]
		var side: int = -1 if (row_index + puzzle.volley_index) % 2 == 0 else 1
		_spawn_arrow(puzzle, row, side, spawner.projectiles_root)
	puzzle.volley_index += 1


func _spawn_arrow(
		puzzle: ArrowGauntletPuzzleInstance,
		row: int,
		side: int,
		projectiles_root: Node2D
	) -> void:
	var arrow: ArrowGauntletProjectile = ARROW_SCENE.instantiate() as ArrowGauntletProjectile
	if arrow == null:
		return
	var source_tile: Vector2i = puzzle.plan.center_tile + Vector2i(
		side * puzzle.definition.emitter_x_offset,
		row
	)
	arrow.direction = Vector2.RIGHT if side < 0 else Vector2.LEFT
	arrow.speed = puzzle.definition.arrow_speed
	arrow.damage = puzzle.definition.arrow_damage
	arrow.building_damage = puzzle.definition.arrow_building_damage
	arrow.lifetime_seconds = puzzle.definition.arrow_lifetime_seconds
	arrow.position = projectiles_root.to_local(
		world_map.navigation_tile_to_world(source_tile)
	)
	projectiles_root.add_child(arrow, true)


func _announce_if_nearby(
		puzzle: ArrowGauntletPuzzleInstance,
		peer_id: int,
		player_tile: Vector2i
	) -> void:
	if puzzle.treasure_claimed or puzzle.announced_peers.has(peer_id):
		return
	var distance: float = Vector2(player_tile).distance_to(Vector2(puzzle.plan.center_tile))
	if distance > float(puzzle.definition.discovery_radius_tiles):
		return
	puzzle.announced_peers[peer_id] = true
	request_peer_message(
		peer_id,
		puzzle.definition.display_name,
		puzzle.definition.instructions,
		"Pfeile von links und rechts",
		"Baue Mauern als Deckung und gehe Schritt für Schritt nach oben.",
		MessageTone.INFO,
		9.0
	)


func _claim_treasure(puzzle: ArrowGauntletPuzzleInstance, peer_id: int) -> void:
	puzzle.treasure_claimed = true
	_set_treasure_claimed.rpc(puzzle.puzzle_index, true)
	_spawn_rewards(puzzle)
	request_peer_message(
		peer_id,
		puzzle.definition.display_name,
		"Du hast den Pfeilpfad mit selbst gebauter Deckung überwunden.",
		"Wald-Rätsel gelöst!",
		"Die Belohnung liegt am Schatz bereit.",
		MessageTone.SUCCESS,
		8.0
	)


func _spawn_rewards(puzzle: ArrowGauntletPuzzleInstance) -> void:
	var spawner: WorldEntitySpawner = WorldEntitySpawner.get_for(self)
	if not is_instance_valid(spawner):
		push_warning("ArrowGauntletPuzzleHandler: WorldEntitySpawner is missing")
		return
	var reward_position: Vector2 = world_map.navigation_tile_to_world(puzzle.treasure_tile)
	for item_value: Variant in puzzle.definition.rewards.keys():
		var item_id: String = String(item_value)
		var amount: int = int(puzzle.definition.rewards[item_value])
		if amount > 0 and Items.item_definitions.has(item_id):
			spawner.spawn_pickups(item_id, reward_position, amount)


func _get_puzzle(index: int) -> ArrowGauntletPuzzleInstance:
	if index < 0 or index >= _puzzles.size():
		return null
	return _puzzles[index]


@rpc("authority", "call_local", "reliable")
func _set_treasure_claimed(puzzle_index: int, claimed: bool) -> void:
	var puzzle: ArrowGauntletPuzzleInstance = _get_puzzle(puzzle_index)
	if puzzle == null:
		return
	puzzle.treasure_claimed = claimed
	if is_instance_valid(puzzle.visual):
		puzzle.visual.set_treasure_claimed(claimed)


@rpc("authority", "call_local", "reliable")
func _sync_puzzle_snapshot(peer_id: int, snapshot: Array[bool]) -> void:
	if multiplayer.get_unique_id() != peer_id:
		return
	for puzzle_index: int in range(mini(snapshot.size(), _puzzles.size())):
		_set_treasure_claimed(puzzle_index, snapshot[puzzle_index])
