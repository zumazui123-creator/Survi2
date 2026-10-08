extends Enemy
class_name VillageResident

var village_id: int = -1
var village_manager: VillageManager


func configure_village(id: int, manager: VillageManager) -> void:
	village_id = id
	village_manager = manager
	spawner = manager


func _update_target() -> void:
	if not is_instance_valid(village_manager):
		village_manager = get_tree().get_first_node_in_group("village_manager") as VillageManager
	if not is_instance_valid(village_manager):
		target_player = null
		return
	target_player = village_manager.get_nearest_intruder(village_id, global_position)
	if is_instance_valid(target_player):
		var target_id: int = int(str(target_player.name))
		if targetPlayerId != target_id:
			targetPlayerId = target_id


func _should_despawn_while_idle() -> bool:
	return false


func _release_spawn_slot() -> void:
	if is_instance_valid(village_manager):
		village_manager.notify_resident_removed(self)
