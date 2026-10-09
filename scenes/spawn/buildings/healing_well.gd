extends BuildingEntity
class_name HealingWellBuilding

@export_range(1.0, 8.0, 0.5) var effect_radius_tiles: float = 3.0
@export_range(0.1, 20.0, 0.5) var healing_per_tick: float = 4.0
@export_range(0.1, 20.0, 0.5) var mana_per_tick: float = 3.0

@onready var regeneration_timer: Timer = $RegenerationTimer


func _ready() -> void:
	super()
	if not regeneration_timer.timeout.is_connected(_on_regeneration_timer_timeout):
		regeneration_timer.timeout.connect(_on_regeneration_timer_timeout)
	if multiplayer.is_server():
		regeneration_timer.start()


func _on_regeneration_timer_timeout() -> void:
	if not multiplayer.is_server() or hp <= 0.0:
		return
	var radius_pixels: float = effect_radius_tiles * float(Constants.TILE_SIZE)
	var radius_squared: float = radius_pixels * radius_pixels
	for candidate: Node in get_tree().get_nodes_in_group(Strings.GROUP_PLAYER):
		var target: Node2D = candidate as Node2D
		if target == null \
				or target.global_position.distance_squared_to(global_position) > radius_squared:
			continue
		var target_stats: PlayerStats = target.get("status") as PlayerStats
		if target_stats == null:
			continue
		target_stats.heal(healing_per_tick)
		target_stats.mana += mana_per_tick
