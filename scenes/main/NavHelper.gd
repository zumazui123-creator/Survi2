extends Node2D

const WALKABLE_TILES = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]  # List of walkable atlas coordinates
const MIN_DISTANCE = 8  # Minimum distance in tiles
const MAX_DISTANCE = 9  # Maximum distance in tiles

@onready var tilemap = $"../Map/TileMap"
#@onready var map = $"../Map"
var map: Node2D
var main: Node2D

func _ready() -> void:
	main = get_node("/root/Game/Level/Main")
	map  = main.get_node("Map")

func getNavigableTiles(playerId, minR, maxR):
	var player = get_parent().get_node_or_null("Players/"+str(playerId))
	if !player:
		return
	var player_tile_pos = tilemap.local_to_map(player.global_position) #todo better pos
	var walkable_tiles = get_walkable_tiles_in_distance(player_tile_pos, minR, maxR)
	
	return walkable_tiles

func getNRandomNavigableTileInPlayerRadius(playerId, n, minR, maxR) -> Array:
	#print("getNRandomNavigableTileInPlayerRadius")
	var tiles = getNavigableTiles(playerId, minR, maxR)
	var randomPositions := []
	if tiles == null or tiles.is_empty():
		return []
	for i in range(n):
		randomPositions.append(tilemap.map_to_local(tiles.pick_random()))
	print(randomPositions)
	return randomPositions

func get_walkable_tiles_in_distance(player_tile_pos: Vector2i, 
				min_distance: int, max_distance: int) -> Array:
	var walkable_tiles = []
	#var visited = {}
	#var queue = []
	var x_dist = 100
	var y_dist = 100
	
	
	for vec in map.walkable_tiles:
		x_dist = abs(player_tile_pos.x-vec.x)
		y_dist = abs(player_tile_pos.y-vec.y)
		if   x_dist > min_distance && x_dist <= max_distance && y_dist == min_distance:
			walkable_tiles.append(vec)
		elif y_dist > min_distance && y_dist <= max_distance && x_dist == min_distance:
			walkable_tiles.append(vec)
				
	
	
	#queue.append([player_tile_pos, 0])  # [tile_position, current_distance]
	#visited[player_tile_pos] = true

	#while queue.size() > 0:
		#var item = queue.pop_front()
		#var current_pos = item[0]
		#var current_dist = item[1]
#
		#if current_dist > max_distance:
			#continue
#
		#if current_dist >= min_distance and is_walkable(current_pos):
			#walkable_tiles.append(current_pos)
#
		#for neighbor in get_neighbors(current_pos):
			#if not visited.has(neighbor):
				#visited[neighbor] = true
				#queue.append([neighbor, current_dist + 1])

	return walkable_tiles

func is_walkable(tile_pos: Vector2i) -> bool:
	var atlas_coord = tilemap.get_cell_atlas_coords(tile_pos)
	return atlas_coord in map.walkable_tiles
	#return atlas_coord in WALKABLE_TILES

func get_neighbors(tile_pos: Vector2i) -> Array:
	var neighbors = [
		tile_pos + Vector2i(1, 0),
		tile_pos + Vector2i(-1, 0),
		tile_pos + Vector2i(0, 1),
		tile_pos + Vector2i(0, -1)
	]

	var valid_neighbors = []
	for neighbor in neighbors:
		if tilemap.get_cell_source_id(neighbor) != -1:  # Check if the cell is valid
			valid_neighbors.append(neighbor)

	return valid_neighbors
