extends Node2D
class_name ProgramPuzzleHandler

enum MessageTone {
	INFO,
	ACTIVE,
	SUCCESS,
	FAILURE,
}

signal peer_message_requested(
	peer_id: int,
	title: String,
	message: String,
	status: String,
	time_text: String,
	tone: int,
	hide_after_seconds: float
)
signal player_tile_memory_requested(peer_id: int, tile: Vector2i)

var world_map: Map


func configure(new_world_map: Map) -> void:
	world_map = new_world_map


func request_peer_message(
		peer_id: int,
		title: String,
		message: String,
		status: String,
		time_text: String,
		tone: int,
		hide_after_seconds: float = 0.0
	) -> void:
	peer_message_requested.emit(
		peer_id,
		title,
		message,
		status,
		time_text,
		tone,
		hide_after_seconds
	)


func request_player_tile_memory(peer_id: int, tile: Vector2i) -> void:
	player_tile_memory_requested.emit(peer_id, tile)


func load_landmarks(_plans: Array[LandmarkPlan]) -> void:
	pass


func clear_handler() -> void:
	pass


func server_tick(_delta: float) -> void:
	pass


func server_observe_player(
		_player: Survi2Player,
		_peer_id: int,
		_tile: Vector2i,
		_tile_changed: bool
	) -> void:
	pass


func sync_peer(_peer_id: int) -> void:
	pass
