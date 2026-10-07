extends Resource
class_name ComboDefinition

@export var combo_id: StringName
@export var display_name: String
@export var input_sequence: PackedStringArray = PackedStringArray()
@export var target_directions: PackedStringArray = PackedStringArray()
## Optional damage pulse count for each matching target direction.  Values align
## with target_directions; omitted values use one pulse.
@export var target_hit_counts: PackedInt32Array = PackedInt32Array()
@export_range(0.0, 100.0, 0.1) var damage_multiplier: float = 1.0
@export_range(1, 10, 1) var damage_pulse_count: int = 1
@export_range(0.0, 5.0, 0.01) var damage_pulse_interval: float = 0.0
@export var visual_effect: StringName
@export_range(0.05, 5.0, 0.01) var effect_duration: float = 0.42


func matches(sequence: PackedStringArray) -> bool:
	if sequence.size() != input_sequence.size():
		return false
	for action_index: int in range(input_sequence.size()):
		if sequence[action_index] != input_sequence[action_index]:
			return false
	return true


func get_target_hit_count(direction_index: int) -> int:
	if direction_index >= 0 and direction_index < target_hit_counts.size():
		return maxi(target_hit_counts[direction_index], 1)
	return 1
