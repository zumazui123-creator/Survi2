extends BuildingEntity
class_name CampfireBuilding

@export var burning: bool = true:
	set(value):
		burning = value
		if is_node_ready():
			_apply_burning_visuals()

@onready var burn_timer: StructureBurnTimer = $BurnTimeComponent
@onready var fire_visuals: Node2D = $Visuals/Fire
@onready var fire_particles: CPUParticles2D = $Visuals/FireParticles
@onready var fire_light: PointLight2D = $Visuals/PointLight2D


func _ready() -> void:
	super()
	if not burn_timer.expired.is_connected(_on_burn_time_expired):
		burn_timer.expired.connect(_on_burn_time_expired)
	_apply_burning_visuals()
	if multiplayer.is_server() and burning:
		burn_timer.start_burning()


func _on_burn_time_expired() -> void:
	if multiplayer.is_server():
		burning = false


func _apply_burning_visuals() -> void:
	if is_instance_valid(fire_visuals):
		fire_visuals.visible = burning
	if is_instance_valid(fire_particles):
		fire_particles.emitting = burning
	if is_instance_valid(fire_light):
		fire_light.enabled = burning

