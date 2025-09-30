extends Control

@onready var player = $".."
@onready var hydrationBar = $Bar/HydrationBar
@onready var foodBar 	  = $Bar/FoodBar
@onready var dayNight 	  = $"../../../dayNight"

var last_time_hydration: int = 0
var last_time_food: int = 0
var hydration_rate: int = 2
var food_rate: int = 5
var playerStatus := {}



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
		playerStatus = {"hp": %hpBar.value, 
		"foodBar": foodBar.value,
		"hydrationBar": hydrationBar.value,
		"moveSpeed": player.move_speed_factor,
		"attackDmg": player.attackDamage,
		"attackRate": player.attackRate,
		"attackRange": player.attackRange,
		"damageType": player.damageType,
		"name": %nameLabel.text,
		"position": [player.position.x, player.position.y],
		"items": Inventory.getItems(str(player.name)),
		"time": 3 #TODO
		}


func _ready() -> void:
	hydrationBar.value = 100
	foodBar.value 	   = 100

func _process(delta: float) -> void:
	if GameTime.get_time() - last_time_hydration > hydration_rate:
		getPlayerStatus()
		print(playerStatus)
		hydrationBar.value -= 1
		last_time_hydration = GameTime.get_time()
		
	if GameTime.get_time() - last_time_food > food_rate:
		foodBar.value -= 1
		last_time_food = GameTime.get_time()
