extends Control

@onready var player = $".."
@onready var hydrationBar = $Bar/HydrationBar
@onready var foodBar 	  = $Bar/FoodBar
@onready var dayNight 	  = $"../../../dayNight"
@onready var player_movement = $"../PlayerMovement"
@onready var player_combat = $"../PlayerCombat"

var last_time_hydration: float = 0
var last_time_food: float = 0
var hydration_rate: float = 2
var food_rate: float = 5


@export var maxHP := 250.0
@export var hp := maxHP:
	set(value):
		hp = value
		$"../bloodParticles".emitting = true
		setHPBarRatio(hp/maxHP)
		if hp <= 0:
			player.player_combat.die()

var status := {"hp": 1,
		"foodBar": 1,
		"hydrationBar": 1,
		"moveSpeed": 1,
		"attackDmg": 1,
		"attackRate": 1,
		"attackRange": 1,
		"damageType": 1,
		"name": "",
		"pixel_position": [1, 1],
		"tile_position": [1, 1],
		"items": "",
		"time": 3, #TODO
		"terminated": false
		}
		
func setPlayerName(newName:String):
	%nameLabel.text = newName
	resizeNameToFit()

func setHPBarRatio(ratio):
	%hpBar.value = ratio

func resizeNameToFit():
	var fontSize = 14
	while %nameLabel.get_line_count() > 1:
		fontSize -= 1
		%nameLabel.set("theme_override_font_sizes/font_size", fontSize)

func getPlayerStatus():
	status = {"hp": hp,
		"foodBar": foodBar.value,
		"hydrationBar": hydrationBar.value,
		"moveSpeed": player_movement.move_speed_factor,
		"attackDmg": player_combat.attackDamage,
		"attackRate": player_combat.attackRate,
		"attackRange": player_combat.attackRange,
		"damageType": player_combat.damageType,
		"name": player.name,
		"pixel_position": [player.position.x, player.position.y],
		"tile_position":[player_movement.current_map_position.x, player_movement.current_map_position.y],
		"items": Inventory.getItems(str(player.name)),
		"time": 3, #TODO
		"terminated": false
		}
	return status


func _ready() -> void:
	hydrationBar.value = 100
	foodBar.value 	   = 100
	getPlayerStatus()


@rpc("authority", "call_local", "reliable")
func get_heal(heal_hp : float):
	hp += heal_hp

func _process(_delta: float) -> void:
	var now = GameTime.get_time()
	if now - last_time_hydration > hydration_rate:
		hydrationBar.value -= 1
		last_time_hydration = now

	if now - last_time_food > food_rate:
		foodBar.value -= 1
		last_time_food = now
