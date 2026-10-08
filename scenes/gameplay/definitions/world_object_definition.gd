extends Resource
class_name WorldObjectDefinition

@export var object_id: StringName
@export var texture: Texture2D
@export var max_hp: float = 40.0
@export var required_tool: StringName
@export var drops: Dictionary = {}
## Zero uses the texture dimensions. Set this only when an object needs a
## deliberately smaller or larger gameplay collision than its sprite.
@export var collision_size: Vector2 = Vector2.ZERO


func get_collision_size() -> Vector2:
	if collision_size.x > 0.0 and collision_size.y > 0.0:
		return collision_size
	if texture != null:
		return texture.get_size()
	return Vector2(Constants.TILE_SIZE, Constants.TILE_SIZE)


func get_occupied_tiles(origin: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var size: Vector2 = get_collision_size()
	var tile_size: float = float(Constants.TILE_SIZE)
	var horizontal_radius: int = maxi(
		ceili((size.x - tile_size) / (tile_size * 2.0)),
		0
	)
	var vertical_radius: int = maxi(
		ceili((size.y - tile_size) / (tile_size * 2.0)),
		0
	)
	for y_offset: int in range(-vertical_radius, vertical_radius + 1):
		for x_offset: int in range(-horizontal_radius, horizontal_radius + 1):
			result.append(origin + Vector2i(x_offset, y_offset))
	return result


func to_legacy_dict() -> Dictionary:
	return {
		"id": String(object_id),
		"hp": max_hp,
		"tool": String(required_tool),
		"drops": drops.duplicate(true),
		"collision_size": get_collision_size(),
	}
