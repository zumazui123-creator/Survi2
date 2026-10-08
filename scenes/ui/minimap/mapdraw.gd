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

#@export var MultiHelper.map.tilemap: TileMapLayer
#@export var player: Node2D
@export var minimap_size: Vector2 = Vector2(256, 256)
@export var tile_size: Vector2 = Vector2(1, 1)

var drawn: bool = false
@onready var world_map: Map = get_tree().get_first_node_in_group("world_map")
@onready var village_manager: VillageManager = get_tree().get_first_node_in_group(
	"village_manager"
) as VillageManager


func _ready() -> void:
	custom_minimum_size = minimap_size
	if is_instance_valid(world_map) \
			and not world_map.generation_started.is_connected(_on_generation_started):
		world_map.generation_started.connect(_on_generation_started)
	if is_instance_valid(village_manager) \
			and not village_manager.villages_changed.is_connected(_on_villages_changed):
		village_manager.villages_changed.connect(_on_villages_changed)


func _draw() -> void:
	if world_map == null or world_map.tile_map == null:
		return
	var used_rect: Rect2i = world_map.tile_map.get_used_rect()
	for x: int in range(used_rect.position.x, used_rect.end.x):
		for y: int in range(used_rect.position.y, used_rect.end.y):
			var cell: int = world_map.tile_map.get_cell_source_id(Vector2i(x, y))
			if cell != -1:
				var cell_atlas_coords: Vector2i = world_map.tile_map.get_cell_atlas_coords(
					Vector2i(x, y)
				)
				var tile_color: Color = WALKABLE_COLOR \
					if cell_atlas_coords in WALKABLE_TILES else DEFAULT_COLOR
				var tile_rect: Rect2 = Rect2(Vector2(x, y) * tile_size, tile_size)
				draw_rect(tile_rect, tile_color)
	_draw_villages()


func _process(_delta: float) -> void:
	if world_map == null:
		return
	if not drawn \
			and world_map.tile_map != null \
			and world_map.tile_map.get_used_rect().size != Vector2i.ZERO:
		queue_redraw()
		drawn = true


func _draw_villages() -> void:
	if not is_instance_valid(village_manager):
		return
	for plan: VillagePlan in village_manager.get_plans():
		var village_rect: Rect2 = Rect2(
			Vector2(plan.bounds.position) * tile_size,
			Vector2(plan.bounds.size) * tile_size
		)
		draw_rect(village_rect, VILLAGE_FILL_COLOR, true)
		draw_rect(village_rect, VILLAGE_BORDER_COLOR, false, 1.0)


func _on_generation_started() -> void:
	drawn = false


func _on_villages_changed() -> void:
	queue_redraw()
