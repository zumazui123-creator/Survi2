extends Node2D
class_name BossTerritoryMarker

var definition: BossTerritoryDefinition
var _marker_offsets: Array[Vector2] = []
var _marker_rotations: Array[float] = []


func configure(value: BossTerritoryDefinition) -> void:
	definition = value
	_rebuild_markers()


func _rebuild_markers() -> void:
	for child: Node in get_children():
		child.queue_free()
	_marker_offsets.clear()
	_marker_rotations.clear()
	if definition == null:
		return

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(String(definition.landmark_id)) ^ int(global_position.x * 31.0) \
		^ int(global_position.y * 17.0)
	var minimum_radius_tiles: int = definition.marker_min_radius_tiles
	if minimum_radius_tiles <= 0:
		minimum_radius_tiles = definition.danger_radius_tiles + 1
	var maximum_radius_tiles: int = definition.marker_max_radius_tiles
	if maximum_radius_tiles <= 0:
		maximum_radius_tiles = maxi(
			definition.warning_radius_tiles - 2,
			definition.danger_radius_tiles + 2
		)
	maximum_radius_tiles = maxi(maximum_radius_tiles, minimum_radius_tiles)
	var minimum_radius: float = float(minimum_radius_tiles) \
		* float(Constants.TILE_SIZE)
	var maximum_radius: float = float(maximum_radius_tiles) \
		* float(Constants.TILE_SIZE)
	var footprint_direction: Vector2 = Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU))
	for index: int in range(definition.marker_count):
		var angle: float
		var offset: Vector2
		if definition.marker_style == BossTerritoryDefinition.MarkerStyle.FOOTPRINTS:
			var progress: float = float(index) / float(maxi(definition.marker_count - 1, 1))
			var footprint_radius: float = lerpf(maximum_radius, minimum_radius, progress)
			var step_side: float = -0.22 if index % 2 == 0 else 0.22
			offset = footprint_direction * footprint_radius \
				+ footprint_direction.orthogonal() * step_side * float(Constants.TILE_SIZE)
			angle = footprint_direction.angle()
		else:
			angle = TAU * float(index) / float(definition.marker_count) \
				+ rng.randf_range(-0.2, 0.2)
			var ring_radius: float = rng.randf_range(minimum_radius, maximum_radius)
			offset = Vector2.RIGHT.rotated(angle) * ring_radius
		_marker_offsets.append(offset)
		_marker_rotations.append(angle + rng.randf_range(-0.35, 0.35))
		if definition.marker_texture != null:
			_add_texture_marker(index)
	queue_redraw()


func _add_texture_marker(index: int) -> void:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = definition.marker_texture
	sprite.position = _marker_offsets[index]
	sprite.rotation = _marker_rotations[index]
	if definition.marker_style == BossTerritoryDefinition.MarkerStyle.FOOTPRINTS:
		sprite.material = _create_silhouette_material()
		sprite.modulate = Color.WHITE
	else:
		sprite.modulate = definition.marker_modulate
	sprite.z_index = -2
	var texture_width: float = maxf(float(sprite.texture.get_width()), 1.0)
	var desired_width: float = definition.marker_width_tiles \
		* float(Constants.TILE_SIZE)
	var uniform_scale: float = desired_width / texture_width
	sprite.scale = Vector2(uniform_scale, uniform_scale)
	add_child(sprite)


func _create_silhouette_material() -> ShaderMaterial:
	var shader: Shader = Shader.new()
	shader.code = "shader_type canvas_item;\n" \
		+ "uniform vec4 tint : source_color;\n" \
		+ "void fragment() {\n" \
		+ "    vec4 source = texture(TEXTURE, UV);\n" \
		+ "    COLOR = vec4(tint.rgb, source.a * tint.a);\n" \
		+ "}"
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("tint", definition.marker_modulate)
	return material


func _draw() -> void:
	if definition == null \
			or definition.marker_style != BossTerritoryDefinition.MarkerStyle.FROST_CRACKS:
		return
	for index: int in range(_marker_offsets.size()):
		var center: Vector2 = _marker_offsets[index]
		var direction: Vector2 = Vector2.RIGHT.rotated(_marker_rotations[index])
		var normal: Vector2 = direction.orthogonal()
		draw_line(center - direction * 22.0, center + direction * 22.0, definition.marker_modulate, 4.0)
		draw_line(center, center + normal * 14.0, definition.marker_modulate, 3.0)
		draw_line(center + direction * 10.0, center - normal * 11.0, definition.marker_modulate, 3.0)
