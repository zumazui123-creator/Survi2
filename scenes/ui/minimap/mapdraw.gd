extends Control

const WALKABLE_TILES: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(1, 0),
	Vector2i(2, 0),
	Vector2i(3, 0),
	Vector2i(16, 0),
	Vector2i(17, 0),
]
const WALKABLE_COLOR: Color = Color(0.0, 1.0, 0.0)
const DEFAULT_COLOR: Color = Color(0.0, 0.0, 1.0, 0.6)
const VILLAGE_FILL_COLOR: Color = Color(0.95, 0.55, 0.12, 0.72)
const VILLAGE_BORDER_COLOR: Color = Color(1.0, 0.9, 0.35, 1.0)
const LARGE_VILLAGE_FILL_COLOR: Color = Color(0.75, 0.22, 0.85, 0.78)
const LARGE_VILLAGE_BORDER_COLOR: Color = Color(1.0, 0.65, 1.0, 1.0)
const LANDMARK_BORDER_COLOR: Color = Color(1.0, 1.0, 1.0, 0.92)
const WORLD_EVENT_BORDER_COLOR: Color = Color(1.0, 0.95, 0.65, 1.0)
const SECRET_BORDER_COLOR: Color = Color(0.7, 1.0, 1.0, 1.0)
const FOG_COLOR: Color = Color(0.015, 0.02, 0.035, 0.96)

#@export var MultiHelper.map.tilemap: TileMapLayer
#@export var player: Node2D
@export var minimap_size: Vector2 = Vector2(256, 256)
@export var tile_size: Vector2 = Vector2(1, 1)

var drawn: bool = false
@onready var world_map: Map = get_tree().get_first_node_in_group("world_map")
@onready var village_manager: VillageManager = get_tree().get_first_node_in_group(
	"village_manager"
) as VillageManager
@onready var landmark_manager: LandmarkManager = get_tree().get_first_node_in_group(
	"landmark_manager"
) as LandmarkManager
@onready var world_event_manager: WorldEventManager = get_tree().get_first_node_in_group(
	"world_event_manager"
) as WorldEventManager
@onready var secret_location_manager: SecretLocationManager = get_tree().get_first_node_in_group(
	"secret_location_manager"
) as SecretLocationManager
@onready var exploration_tracker: MapExplorationTracker = get_tree().get_first_node_in_group(
	"map_exploration_tracker"
) as MapExplorationTracker


func _ready() -> void:
	custom_minimum_size = minimap_size
	if is_instance_valid(world_map) \
			and not world_map.generation_started.is_connected(_on_generation_started):
		world_map.generation_started.connect(_on_generation_started)
	if is_instance_valid(village_manager) \
			and not village_manager.villages_changed.is_connected(_on_villages_changed):
		village_manager.villages_changed.connect(_on_villages_changed)
	if is_instance_valid(landmark_manager) \
			and not landmark_manager.landmarks_changed.is_connected(_on_landmarks_changed):
		landmark_manager.landmarks_changed.connect(_on_landmarks_changed)
	if is_instance_valid(world_event_manager) \
			and not world_event_manager.events_changed.is_connected(_on_world_events_changed):
		world_event_manager.events_changed.connect(_on_world_events_changed)
	if is_instance_valid(secret_location_manager) \
			and not secret_location_manager.secrets_changed.is_connected(_on_secrets_changed):
		secret_location_manager.secrets_changed.connect(_on_secrets_changed)
	_connect_exploration_tracker()


func _draw() -> void:
	if world_map == null or world_map.tile_map == null:
		return
	var used_rect: Rect2i = world_map.tile_map.get_used_rect()
	draw_rect(
		Rect2(Vector2(used_rect.position) * tile_size, Vector2(used_rect.size) * tile_size),
		FOG_COLOR,
		true
	)
	if not is_instance_valid(exploration_tracker):
		return
	for tile: Vector2i in exploration_tracker.get_explored_tiles():
		var cell: int = world_map.tile_map.get_cell_source_id(tile)
		if cell != -1:
			var cell_atlas_coords: Vector2i = world_map.tile_map.get_cell_atlas_coords(
				tile
			)
			var biome_definition: BiomeDefinition = world_map.get_biome_definition_at(tile)
			var tile_color: Color = DEFAULT_COLOR
			if cell_atlas_coords in world_map.waterCoors:
				tile_color = DEFAULT_COLOR
			elif biome_definition != null:
				tile_color = biome_definition.map_color
			elif cell_atlas_coords in WALKABLE_TILES:
				tile_color = WALKABLE_COLOR
			var tile_rect: Rect2 = Rect2(Vector2(tile) * tile_size, tile_size)
			draw_rect(tile_rect, tile_color)
	_draw_villages()
	_draw_landmarks()
	_draw_world_events()
	_draw_secret_locations()


func _process(_delta: float) -> void:
	if world_map == null:
		return
	if not is_instance_valid(exploration_tracker):
		exploration_tracker = get_tree().get_first_node_in_group(
			"map_exploration_tracker"
		) as MapExplorationTracker
		_connect_exploration_tracker()
	if not drawn \
			and world_map.tile_map != null \
			and world_map.tile_map.get_used_rect().size != Vector2i.ZERO:
		queue_redraw()
		drawn = true


func _draw_villages() -> void:
	if not is_instance_valid(village_manager):
		return
	for plan: VillagePlan in village_manager.get_plans():
		if not is_instance_valid(exploration_tracker) \
				or not exploration_tracker.is_village_discovered(plan):
			continue
		var village_rect: Rect2 = Rect2(
			Vector2(plan.bounds.position) * tile_size,
			Vector2(plan.bounds.size) * tile_size
		)
		var role: VillageRoleDefinition = village_manager.get_role_for_plan(plan)
		var fill_color: Color = role.map_color if role != null else VILLAGE_FILL_COLOR
		fill_color.a = 0.72
		var border_color: Color = role.map_color.lightened(0.25) \
			if role != null else VILLAGE_BORDER_COLOR
		if plan.is_large and role == null:
			fill_color = LARGE_VILLAGE_FILL_COLOR
			border_color = LARGE_VILLAGE_BORDER_COLOR
		draw_rect(village_rect, fill_color, true)
		draw_rect(village_rect, border_color, false, 1.0)


func _on_generation_started() -> void:
	drawn = false


func _on_villages_changed() -> void:
	queue_redraw()


func _draw_landmarks() -> void:
	if not is_instance_valid(landmark_manager):
		return
	for plan: LandmarkPlan in landmark_manager.get_plans():
		if not is_instance_valid(exploration_tracker) \
				or not exploration_tracker.is_landmark_discovered(plan):
			continue
		var definition: LandmarkDefinition = landmark_manager.get_definition(
			plan.landmark_id
		)
		var color: Color = definition.map_color if definition != null \
			else Color(0.65, 0.65, 0.65, 0.8)
		var landmark_rect: Rect2 = Rect2(
			Vector2(plan.bounds.position) * tile_size,
			Vector2(plan.bounds.size) * tile_size
		)
		draw_rect(landmark_rect, Color(color.r, color.g, color.b, 0.82), true)
		draw_rect(landmark_rect, LANDMARK_BORDER_COLOR, false, 1.0)


func _on_landmarks_changed() -> void:
	queue_redraw()


func _draw_world_events() -> void:
	if not is_instance_valid(world_event_manager):
		return
	for plan: WorldEventPlan in world_event_manager.get_active_plans():
		if not is_instance_valid(exploration_tracker) \
				or not exploration_tracker.is_world_event_discovered(plan):
			continue
		var definition: WorldEventDefinition = world_event_manager.get_definition(
			plan.event_id
		)
		var color: Color = definition.map_color if definition != null \
			else Color(1.0, 0.72, 0.15, 1.0)
		var center: Vector2 = Vector2(plan.center_tile) * tile_size + tile_size * 0.5
		draw_circle(center, 3.0, color)
		draw_arc(center, 4.5, 0.0, TAU, 12, WORLD_EVENT_BORDER_COLOR, 1.0)


func _on_world_events_changed() -> void:
	queue_redraw()


func _draw_secret_locations() -> void:
	if not is_instance_valid(secret_location_manager):
		return
	for plan: SecretLocationPlan in secret_location_manager.get_plans():
		if not secret_location_manager.is_revealed(plan.plan_id):
			continue
		var definition: SecretLocationDefinition = secret_location_manager.get_definition(
			plan.secret_id
		)
		var color: Color = definition.map_color if definition != null \
			else Color(0.35, 0.9, 0.95, 1.0)
		var center: Vector2 = Vector2(plan.center_tile) * tile_size + tile_size * 0.5
		draw_circle(center, 2.5, color)
		draw_arc(center, 4.0, 0.0, TAU, 12, SECRET_BORDER_COLOR, 1.0)


func _on_secrets_changed() -> void:
	queue_redraw()


func _connect_exploration_tracker() -> void:
	if is_instance_valid(exploration_tracker) \
			and not exploration_tracker.exploration_changed.is_connected(
				_on_exploration_changed
			):
		exploration_tracker.exploration_changed.connect(_on_exploration_changed)


func _on_exploration_changed() -> void:
	queue_redraw()
