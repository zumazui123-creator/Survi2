extends BuildingEntity
class_name TeleportPadBuilding

const COOLDOWN_META: StringName = &"teleport_pad_cooldown_until"
const AIRBORNE_META: StringName = &"jump_pad_airborne"

@export_range(100, 5000, 100) var retrigger_cooldown_ms: int = 1000
@export_range(0.05, 1.0, 0.05) var teleport_duration: float = 0.15

@onready var teleport_area: Area2D = $TeleportArea
var partner: TeleportPadBuilding
var _network: TeleportNetwork


func _ready() -> void:
	super()
	_network = get_tree().get_first_node_in_group(&"teleport_network") as TeleportNetwork
	if is_instance_valid(_network):
		_network.register_pad(self)
	if not teleport_area.body_entered.is_connected(_on_body_entered):
		teleport_area.body_entered.connect(_on_body_entered)


func _exit_tree() -> void:
	if is_instance_valid(_network):
		_network.unregister_pad(self)


func set_partner(value: TeleportPadBuilding) -> void:
	partner = value
	var glow: CanvasItem = get_node_or_null("Visuals/Glow") as CanvasItem
	if glow != null:
		glow.modulate = Color(0.35, 1.0, 1.0, 1.0) if value != null \
			else Color(0.45, 0.45, 0.55, 0.55)


func _on_body_entered(body: Node2D) -> void:
	if not multiplayer.is_server() \
			or not is_instance_valid(partner) \
			or not _can_teleport(body):
		return
	var destination: Vector2 = partner.global_position
	var cooldown_until: int = Time.get_ticks_msec() + retrigger_cooldown_ms
	body.set_meta(COOLDOWN_META, cooldown_until)
	if body.is_in_group(Strings.GROUP_PLAYER):
		body.rpc("launch_from_jump_pad", destination, teleport_duration)
		return
	body.set_meta(AIRBORNE_META, true)
	var tween: Tween = body.create_tween()
	tween.tween_property(body, "global_position", destination, teleport_duration)
	await tween.finished
	if not is_instance_valid(body):
		return
	body.remove_meta(AIRBORNE_META)
	var navigation: EnemyNavigation = body.get_node_or_null(
		"EnemyNavigation"
	) as EnemyNavigation
	if navigation != null:
		navigation.synchronize_after_external_move()


func _can_teleport(body: Node2D) -> bool:
	if not is_instance_valid(body):
		return false
	if not body.is_in_group(Strings.GROUP_PLAYER) \
			and not body.is_in_group(&"sensor_enemy") \
			and not body.is_in_group(&"sensor_animal"):
		return false
	return int(body.get_meta(COOLDOWN_META, 0)) <= Time.get_ticks_msec()
