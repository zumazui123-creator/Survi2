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
		"pixel_position": [player.position.x, player.position.y],
		"tile_position":[player.current_map_position.x, player.current_map_position.y],
		"items": Inventory.getItems(str(player.name)),
		"time": 3, #TODO
		"terminated": false
		}
	return playerStatus


func _ready() -> void:
	hydrationBar.value = 100
	foodBar.value 	   = 100
	Inventory.itemConsumed.connect(_on_item_consumed)

func _on_item_consumed(id, effects):
	if str(player.name) != id: # Ensure this is for the current player
		return

	if "hp" in effects:
		player.hp = min(player.maxHP, player.hp + effects["hp"])
	if "food" in effects:
		foodBar.value = min(100, foodBar.value + effects["food"])
	if "hydration" in effects:
		hydrationBar.value = min(100, hydrationBar.value + effects["hydration"])

func _process(delta: float) -> void:
	var now = GameTime.get_time()
	if now - last_time_hydration > hydration_rate:
		hydrationBar.value -= 1
		last_time_hydration = now

	if now - last_time_food > food_rate:
		foodBar.value -= 1
		last_time_food = now
