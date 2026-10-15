extends Node2D
class_name ProgramPuzzleManager

@export var world_map: Map
@export var hud_scene: PackedScene
@export_range(0.05, 0.5, 0.05) var player_scan_interval: float = 0.1

var _handlers: Array[ProgramPuzzleHandler] = []
var _last_player_tiles: Dictionary[int, Vector2i] = {}
var _synced_peers: Dictionary[int, bool] = {}
var _scan_remaining: float = 0.0
var _local_hud: ProgramPuzzleHUD


func _ready() -> void:
	_refresh_handlers()


func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	for handler: ProgramPuzzleHandler in _handlers:
		handler.server_tick(delta)
	_scan_remaining -= delta
	if _scan_remaining > 0.0:
		return
	_scan_remaining = player_scan_interval
	_scan_players()


func load_puzzles(plans: Array[LandmarkPlan]) -> void:
	_refresh_handlers()
	_last_player_tiles.clear()
	_synced_peers.clear()
	for handler: ProgramPuzzleHandler in _handlers:
		handler.clear_handler()
		handler.load_landmarks(plans)


func clear_puzzles() -> void:
	for handler: ProgramPuzzleHandler in _handlers:
		handler.clear_handler()
	_last_player_tiles.clear()
	_synced_peers.clear()
	if is_instance_valid(_local_hud):
		_local_hud.hide_immediately()


func show_peer_message(
		peer_id: int,
		title: String,
		message: String,
		status: String,
		time_text: String,
		tone: int = ProgramPuzzleHandler.MessageTone.INFO,
		hide_after_seconds: float = 0.0
	) -> void:
	if not multiplayer.is_server() or peer_id < 0:
		return
	_show_peer_message.rpc(
		peer_id,
		title,
		message,
		status,
		time_text,
		int(tone),
		hide_after_seconds
	)


func remember_player_tile(peer_id: int, tile: Vector2i) -> void:
	_last_player_tiles[peer_id] = tile


func _refresh_handlers() -> void:
	_handlers.clear()
	for child: Node in get_children():
		var handler: ProgramPuzzleHandler = child as ProgramPuzzleHandler
		if handler == null:
			continue
		handler.configure(world_map)
		if not handler.peer_message_requested.is_connected(show_peer_message):
			handler.peer_message_requested.connect(show_peer_message)
		if not handler.player_tile_memory_requested.is_connected(
			remember_player_tile
		):
			handler.player_tile_memory_requested.connect(remember_player_tile)
		_handlers.append(handler)


func _scan_players() -> void:
	for candidate: Node in get_tree().get_nodes_in_group("player"):
		var player: Survi2Player = candidate as Survi2Player
		if player == null:
			continue
		var peer_id: int = player.get_multiplayer_authority()
		if not _synced_peers.has(peer_id):
			_synced_peers[peer_id] = true
			for handler: ProgramPuzzleHandler in _handlers:
				handler.sync_peer(peer_id)
		var tile: Vector2i = world_map.world_to_navigation_tile(
			player.global_position
		)
		var tile_changed: bool = _last_player_tiles.get(
			peer_id,
			Vector2i(-999999, -999999)
		) != tile
		if tile_changed:
			_last_player_tiles[peer_id] = tile
		for handler: ProgramPuzzleHandler in _handlers:
			handler.server_observe_player(
				player,
				peer_id,
				tile,
				tile_changed
			)


@rpc("authority", "call_local", "reliable")
func _show_peer_message(
		peer_id: int,
		title: String,
		message: String,
		status: String,
		time_text: String,
		tone: int,
		hide_after_seconds: float
	) -> void:
	if multiplayer.get_unique_id() != peer_id:
		return
	var hud: ProgramPuzzleHUD = _get_local_hud()
	if hud != null:
		hud.present(
			title,
			message,
			status,
			time_text,
			tone,
			hide_after_seconds
		)


func _get_local_hud() -> ProgramPuzzleHUD:
	if is_instance_valid(_local_hud):
		return _local_hud
	_local_hud = get_tree().get_first_node_in_group(
		"program_puzzle_hud"
	) as ProgramPuzzleHUD
	if is_instance_valid(_local_hud):
		return _local_hud
	if hud_scene == null:
		return null
	var world_hud: Node = get_tree().get_first_node_in_group("world_hud")
	if world_hud == null:
		return null
	_local_hud = hud_scene.instantiate() as ProgramPuzzleHUD
	if _local_hud != null:
		world_hud.add_child(_local_hud)
	return _local_hud
