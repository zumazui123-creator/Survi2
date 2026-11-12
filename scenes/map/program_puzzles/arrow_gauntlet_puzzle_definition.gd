extends ProgramPuzzleDefinitionBase
class_name ArrowGauntletPuzzleDefinition

@export_group("Layout")
@export var start_offset: Vector2i = Vector2i(0, 7)
@export var treasure_offset: Vector2i = Vector2i(0, -7)
@export var hazard_row_offsets: PackedInt32Array = PackedInt32Array([-5, -3, -1, 1, 3, 5])
@export_range(2, 6, 1) var barrier_x_offset: int = 3
@export_range(3, 12, 1) var barrier_half_height: int = 8
@export_range(1, 5, 1) var emitter_x_offset: int = 2

@export_group("Arrows")
@export_range(0.2, 5.0, 0.05) var volley_interval_seconds: float = 1.25
@export_range(50.0, 1000.0, 10.0) var arrow_speed: float = 430.0
@export_range(1.0, 100.0, 1.0) var arrow_damage: float = 10.0
@export_range(0.0, 100.0, 1.0) var arrow_building_damage: float = 4.0
@export_range(0.2, 5.0, 0.1) var arrow_lifetime_seconds: float = 1.2
@export_range(2, 24, 1) var activation_radius_tiles: int = 11


func is_valid() -> bool:
	return is_common_valid() \
		and not hazard_row_offsets.is_empty() \
		and barrier_x_offset > emitter_x_offset \
		and emitter_x_offset > 0 \
		and barrier_half_height > 0 \
		and volley_interval_seconds > 0.0 \
		and arrow_speed > 0.0 \
		and arrow_lifetime_seconds > 0.0
