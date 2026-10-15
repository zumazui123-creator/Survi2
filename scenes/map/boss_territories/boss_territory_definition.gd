extends Resource
class_name BossTerritoryDefinition

enum MarkerStyle {
	BROKEN_TREES,
	FOOTPRINTS,
	FROST_CRACKS,
}

@export var landmark_id: StringName
@export var boss_actor_id: StringName
@export var boss_name: String
@export_multiline var approach_warning: String
@export_multiline var villager_warning: String
@export_range(4, 64, 1) var warning_radius_tiles: int = 18
@export_range(2, 48, 1) var danger_radius_tiles: int = 10
@export_range(0.0, 12.0, 0.25) var shake_strength: float = 2.0
@export_range(0.1, 4.0, 0.1) var shake_duration: float = 0.5
@export_range(0.5, 12.0, 0.5) var shake_interval: float = 4.0
@export_group("Territory markers")
@export var marker_style: MarkerStyle = MarkerStyle.BROKEN_TREES
@export var marker_texture: Texture2D
@export_range(1, 32, 1) var marker_count: int = 10
@export_range(0.25, 4.0, 0.05) var marker_width_tiles: float = 1.0
@export_range(0, 64, 1) var marker_min_radius_tiles: int = 0
@export_range(0, 64, 1) var marker_max_radius_tiles: int = 0
@export var marker_modulate: Color = Color.WHITE
@export_group("Music")
@export var music: AudioStream
@export_range(-40.0, 0.0, 1.0) var music_volume_db: float = -10.0
@export_range(0.0, 120.0, 0.1) var music_loop_offset_seconds: float = 0.0


func is_valid() -> bool:
	return not landmark_id.is_empty() \
		and not boss_actor_id.is_empty() \
		and not boss_name.is_empty()
