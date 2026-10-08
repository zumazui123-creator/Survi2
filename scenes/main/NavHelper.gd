extends Node2D

const WALKABLE_TILES = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]  # List of walkable atlas coordinates
const MIN_DISTANCE = 8  # Minimum distance in tiles
const MAX_DISTANCE = 9  # Maximum distance in tiles

@export var tilemap: TileMapLayer
@export var map: Map
@export var players_root: Node2D

func getNavigableTiles(playerId, minR, maxR):
	var player = players_root.get_node_or_null(str(playerId))
	if !player:
		return []
	var player_tile_pos = map.world_to_navigation_tile(player.global_position)
	var walkable_tiles = get_walkable_tiles_in_distance(player_tile_pos, minR, maxR)
	
	return walkable_tiles

func getNRandomNavigableTileInPlayerRadius(playerId, n, minR, maxR) -> Array:
	#print("getNRandomNavigableTileInPlayerRadius")
	var tiles = getNavigableTiles(playerId, minR, maxR)
	var randomPositions := []
	if tiles == null or tiles.is_empty():
		return []
	tiles.shuffle()
	var player := players_root.get_node_or_null(str(playerId)) as Node2D
	if player == null:
		return []
	var player_tile := map.world_to_navigation_tile(player.global_position)
	for tile: Vector2i in tiles:
		if map.get_navigation_path(tile, player_tile).is_empty():
			continue
		randomPositions.append(map.navigation_tile_to_world(tile))
		if randomPositions.size() >= n:
			break
	return randomPositions

func get_walkable_tiles_in_distance(player_tile_pos: Vector2i, 
				min_distance: int, max_distance: int) -> Array:
	var walkable_tiles = []
	#var visited = {}
	#var queue = []
	var x_dist: int
	var y_dist: int
	for vec in map.walkable_tiles:
		if not map.is_navigation_tile_walkable(vec, true):
			continue
		if map.is_village_tile(vec):
			continue
		x_dist = abs(player_tile_pos.x-vec.x)
		y_dist = abs(player_tile_pos.y-vec.y)
		var tile_distance := maxi(x_dist, y_dist)
		if tile_distance > min_distance and tile_distance <= max_distance:
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
	return map.is_navigation_tile_walkable(tile_pos, true)

func get_neighbors(tile_pos: Vector2i) -> Array:
	var neighbors = [
		tile_pos + Vector2i(1, 0),
		tile_pos + Vector2i(-1, 0),
		tile_pos + Vector2i(0, 1),
		tile_pos + Vector2i(0, -1)
	]

	var valid_neighbors = []
	for neighbor in neighbors:
		if is_walkable(neighbor):
			valid_neighbors.append(neighbor)

	return valid_neighbors
