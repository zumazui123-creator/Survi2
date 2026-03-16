extends Node2D


@export var layer : TileMapLayer
var walkable_tiles = []


func get_walkable_tiles(
		grass_atlas_coords
	) :
	walkable_tiles = []

	for cell in layer.get_used_cells():
		var atlas = layer.get_cell_atlas_coords(cell)

		if atlas in grass_atlas_coords:
			walkable_tiles.append(cell)

	return walkable_tiles
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
