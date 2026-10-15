extends RefCounted
class_name TimedMazeGenerator

const DIRECTIONS: Array[Vector2i] = [
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.UP,
]


func generate(bounds: Rect2i, seed_value: int) -> Dictionary:
	var width: int = _normalized_dimension(bounds.size.x)
	var height: int = _normalized_dimension(bounds.size.y)
	var origin: Vector2i = bounds.position
	var walls: Dictionary[Vector2i, bool] = {}
	for local_y: int in range(height):
		for local_x: int in range(width):
			walls[origin + Vector2i(local_x, local_y)] = true

	var start_cell: Vector2i = Vector2i(1, height - 2)
	var start_tile: Vector2i = origin + Vector2i(1, height - 1)
	var visited: Dictionary[Vector2i, bool] = {}
	var depths: Dictionary[Vector2i, int] = {}
	visited[start_cell] = true
	depths[start_cell] = 0
	var stack: Array[Vector2i] = [start_cell]
	var farthest_cell: Vector2i = start_cell
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	walls.erase(origin + start_cell)
	walls.erase(start_tile)

	while not stack.is_empty():
		var current: Vector2i = stack[stack.size() - 1]
		var candidates: Array[Vector2i] = _get_unvisited_neighbors(
			current, width, height, visited
		)
		if candidates.is_empty():
			stack.pop_back()
			continue
		var next: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
		var corridor_direction: Vector2i = Vector2i(
			signi(next.x - current.x),
			signi(next.y - current.y)
		)
		var corridor: Vector2i = current + corridor_direction
		walls.erase(origin + corridor)
		walls.erase(origin + next)
		visited[next] = true
		depths[next] = int(depths[current]) + 1
		if int(depths[next]) > int(depths[farthest_cell]):
			farthest_cell = next
		stack.append(next)

	var wall_tiles: Array[Vector2i] = []
	for tile: Vector2i in walls:
		wall_tiles.append(tile)
	return {
		"wall_tiles": wall_tiles,
		"start_tile": start_tile,
		"goal_tile": origin + farthest_cell,
	}


func _get_unvisited_neighbors(
		cell: Vector2i,
		width: int,
		height: int,
		visited: Dictionary[Vector2i, bool]
	) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction: Vector2i in DIRECTIONS:
		var candidate: Vector2i = cell + direction * 2
		if candidate.x < 1 or candidate.y < 1 \
				or candidate.x >= width - 1 or candidate.y >= height - 1 \
				or visited.has(candidate):
			continue
		result.append(candidate)
	return result


func _normalized_dimension(value: int) -> int:
	var normalized: int = maxi(value, 5)
	if normalized % 2 == 0:
		normalized -= 1
	return normalized
