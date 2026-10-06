extends Node
class_name PlayerDeathHandler

@export var stats: PlayerStats
@export var combat: PlayerCombat
@export var blood_particles: CPUParticles2D


func _ready() -> void:
	stats.died.connect(_on_player_died)


func _on_player_died() -> void:
	if is_instance_valid(blood_particles):
		blood_particles.restart()
		blood_particles.emitting = true
	combat.die()
