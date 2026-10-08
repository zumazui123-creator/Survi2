extends BuildingEntity
class_name DefenseTower

@onready var attack_cooldown: Timer = $AttackCooldown
@onready var moving_parts: Node2D = $MovingParts
@onready var target_finder: TowerTargetFinder = $TargetFinder
@onready var weapon: TowerWeapon = $TowerWeapon


func _ready() -> void:
	super()
	attack_cooldown.wait_time = weapon.attack_interval
	attack_cooldown.start()


func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server() or hp <= 0.0 or not loaded:
		return
	if not attack_cooldown.is_stopped():
		return
	attack_cooldown.start()
	var target: Node2D = target_finder.find_nearest(self)
	if target == null:
		return
	moving_parts.look_at(target.global_position)
	weapon.fire(self, target, target_finder.target_group)
