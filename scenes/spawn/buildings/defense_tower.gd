extends NavigationBuilding
class_name DefenseTower

const ENEMY_GROUP: StringName = &"sensor_enemy"

@export_range(1.0, 20.0, 0.5) var attack_range_tiles: float = 6.0
@export_range(0.1, 60.0, 0.5) var attack_damage: float = 15.0
@export_range(0.1, 10.0, 0.1) var attack_interval: float = 1.25
@export var projectile_id: String = "magicBolt"
@export var damage_type: StringName = &"normal"

@onready var attack_cooldown: Timer = $AttackCooldown
@onready var moving_parts: Node2D = $MovingParts


func _ready() -> void:
	super()
	attack_cooldown.wait_time = attack_interval
	attack_cooldown.start()


func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server() or hp <= 0.0 or not loaded:
		return
	if not attack_cooldown.is_stopped():
		return
	attack_cooldown.start()
	var target: Node2D = _find_nearest_enemy()
	if target == null:
		return
	moving_parts.look_at(target.global_position)
	var entity_spawner: WorldEntitySpawner = WorldEntitySpawner.get_for(self)
	if entity_spawner == null:
		return
	entity_spawner.spawn_projectile(
		self,
		projectile_id,
		target.global_position,
		ENEMY_GROUP,
		_on_projectile_hit
	)


func get_navigation_tiles(origin: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = [origin]
	return result


func _find_nearest_enemy() -> Node2D:
	var nearest_enemy: Node2D
	var nearest_distance_squared: float = INF
	var maximum_distance: float = attack_range_tiles * float(Constants.TILE_SIZE)
	var maximum_distance_squared: float = maximum_distance * maximum_distance
	for candidate: Node in get_tree().get_nodes_in_group(ENEMY_GROUP):
		var enemy: Node2D = candidate as Node2D
		if enemy == null or enemy.is_queued_for_deletion() or not enemy.has_method("getDamage"):
			continue
		var distance_squared: float = global_position.distance_squared_to(enemy.global_position)
		if distance_squared <= maximum_distance_squared \
				and distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest_enemy = enemy
	return nearest_enemy


func _on_projectile_hit(body: Node) -> void:
	if not multiplayer.is_server() \
			or not is_instance_valid(body) \
			or not body.is_in_group(ENEMY_GROUP) \
			or not body.has_method("getDamage"):
		return
	body.call("getDamage", self, attack_damage, damage_type)
