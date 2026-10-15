extends Node2D
class_name BossTerritoryManager

@export var world_map: Map
@export var village_manager: VillageManager
@export var definitions: Array[BossTerritoryDefinition] = []
@export var warning_scene: PackedScene
@export var music_player: AudioStreamPlayer
@export_range(0.05, 1.0, 0.05) var scan_interval: float = 0.25
@export_range(1.0, 40.0, 1.0) var music_fade_speed: float = 14.0

var _definitions_by_landmark: Dictionary[StringName, BossTerritoryDefinition] = {}
var _territories: Array[BossTerritoryState] = []
var _warning_ui: BossTerritoryWarning
var _scan_remaining: float = 0.0
var _music_wanted: bool = false
var _wanted_music: AudioStream
var _wanted_music_volume_db: float = -10.0
var _wanted_loop_offset_seconds: float = 0.0


func _ready() -> void:
	_rebuild_definition_index()
	if is_instance_valid(music_player):
		music_player.volume_db = -40.0


func _process(delta: float) -> void:
	_update_music(delta)
	for territory: BossTerritoryState in _territories:
		territory.shake_cooldown = maxf(territory.shake_cooldown - delta, 0.0)
	_scan_remaining -= delta
	if _scan_remaining > 0.0:
		return
	_scan_remaining = scan_interval
	_scan_local_player()


func load_territories(plans: Array[LandmarkPlan]) -> void:
	clear_territories()
	_rebuild_definition_index()
	if not is_instance_valid(world_map):
		return
	for plan: LandmarkPlan in plans:
		var definition: BossTerritoryDefinition = _definitions_by_landmark.get(
			plan.landmark_id
		) as BossTerritoryDefinition
		if definition == null:
			continue
		var state: BossTerritoryState = BossTerritoryState.new(definition, plan)
		var marker: BossTerritoryMarker = BossTerritoryMarker.new()
		marker.name = "Territory_%s" % String(plan.landmark_id)
		add_child(marker)
		marker.global_position = world_map.navigation_tile_to_world(plan.center_tile)
		marker.configure(definition)
		state.marker = marker
		_territories.append(state)


func clear_territories() -> void:
	for territory: BossTerritoryState in _territories:
		if is_instance_valid(territory.marker):
			territory.marker.queue_free()
	_territories.clear()
	_music_wanted = false
	_wanted_music = null
	if is_instance_valid(music_player):
		music_player.stop()
		music_player.volume_db = -40.0
	if is_instance_valid(_warning_ui):
		_warning_ui.hide_warning()


func _rebuild_definition_index() -> void:
	_definitions_by_landmark.clear()
	for definition: BossTerritoryDefinition in definitions:
		if definition != null and definition.is_valid():
			_definitions_by_landmark[definition.landmark_id] = definition


func _scan_local_player() -> void:
	var player: Survi2Player = _get_local_player()
	if player == null or not is_instance_valid(world_map):
		_music_wanted = false
		_wanted_music = null
		return
	var player_tile: Vector2i = world_map.world_to_navigation_tile(player.global_position)
	var nearest: BossTerritoryState
	var nearest_distance: float = INF
	var nearest_music_distance: float = INF
	_music_wanted = false
	_wanted_music = null
	for territory: BossTerritoryState in _territories:
		_update_boss_presence(territory)
		if territory.boss_defeated:
			continue
		var distance: float = territory.get_distance_to(player_tile)
		if distance < nearest_distance:
			nearest = territory
			nearest_distance = distance
		if distance <= float(territory.definition.warning_radius_tiles):
			if territory.definition.music != null and distance < nearest_music_distance:
				_music_wanted = true
				nearest_music_distance = distance
				_wanted_music = territory.definition.music
				_wanted_music_volume_db = territory.definition.music_volume_db
				_wanted_loop_offset_seconds = territory.definition.music_loop_offset_seconds
			if not territory.approach_warning_shown:
				territory.approach_warning_shown = true
				_show_warning(
					"Boss-Territorium: %s" % territory.definition.boss_name,
					territory.definition.approach_warning,
					Color(1.0, 0.38, 0.16, 1.0)
				)
		if distance <= float(territory.definition.danger_radius_tiles) \
				and territory.shake_cooldown <= 0.0:
			_shake_player_camera(player, territory.definition)
			territory.shake_cooldown = territory.definition.shake_interval
	if nearest != null \
			and not nearest.villager_warning_shown \
			and nearest_distance > float(nearest.definition.warning_radius_tiles) \
			and is_instance_valid(village_manager) \
			and village_manager.is_tile_in_any_village(player_tile):
		nearest.villager_warning_shown = true
		_show_warning(
			"Warnung eines Dorfbewohners",
			nearest.definition.villager_warning,
			Color(1.0, 0.82, 0.28, 1.0)
		)


func _update_boss_presence(territory: BossTerritoryState) -> void:
	var search_radius: float = float(territory.definition.warning_radius_tiles + 8) \
		* float(Constants.TILE_SIZE)
	var center: Vector2 = world_map.navigation_tile_to_world(territory.plan.center_tile)
	for candidate: Node in get_tree().get_nodes_in_group("boss"):
		var boss: BossCreature = candidate as BossCreature
		if boss == null or boss.actor_id != territory.definition.boss_actor_id:
			continue
		if boss.global_position.distance_to(center) <= search_radius:
			territory.boss_seen = true
			return
	if territory.boss_seen:
		territory.boss_defeated = true


func _get_local_player() -> Survi2Player:
	for candidate: Node in get_tree().get_nodes_in_group("player"):
		var player: Survi2Player = candidate as Survi2Player
		if player != null and player.is_multiplayer_authority():
			return player
	return null


func _shake_player_camera(
		player: Survi2Player,
		definition: BossTerritoryDefinition
	) -> void:
	var camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	if camera != null and camera.has_method("shake"):
		camera.call("shake", definition.shake_strength, definition.shake_duration)


func _show_warning(title: String, message: String, accent: Color) -> void:
	if message.is_empty():
		return
	if not is_instance_valid(_warning_ui):
		_create_warning_ui()
	if is_instance_valid(_warning_ui):
		_warning_ui.show_warning(title, message, accent)


func _create_warning_ui() -> void:
	if warning_scene == null:
		return
	var hud: Node = get_tree().get_first_node_in_group("world_hud")
	if hud == null:
		return
	_warning_ui = warning_scene.instantiate() as BossTerritoryWarning
	if _warning_ui != null:
		hud.add_child(_warning_ui)


func _update_music(delta: float) -> void:
	if not is_instance_valid(music_player):
		return
	if _music_wanted and _wanted_music != null \
			and music_player.stream != _wanted_music:
		music_player.stop()
		music_player.stream = _wanted_music
		_configure_music_loop()
		music_player.volume_db = -40.0
	if _music_wanted and music_player.stream != null and not music_player.playing:
		music_player.volume_db = -40.0
		music_player.play()
	var target_volume: float = _wanted_music_volume_db \
		if _music_wanted and _wanted_music != null else -40.0
	music_player.volume_db = move_toward(
		music_player.volume_db,
		target_volume,
		music_fade_speed * delta
	)
	if not _music_wanted and music_player.playing \
			and music_player.volume_db <= -39.5:
		music_player.stop()


func _configure_music_loop() -> void:
	var ogg_stream: AudioStreamOggVorbis = music_player.stream as AudioStreamOggVorbis
	if ogg_stream == null:
		return
	ogg_stream.loop = true
	ogg_stream.loop_offset = _wanted_loop_offset_seconds
