extends Node
@onready var spawn_list : OptionButton =  %OptionSpawn
@onready var spawn_texture : TextureRect = %TextureSpawn
var mobs: Array = []


func init_spawn_list() -> void:
	for mob in mobs:
		spawn_list.add_item(mob)
		
func update_incon(text : String):
	print("update icon")
	spawn_texture.texture = Items.get_actor_texture(text)
	spawn_texture.tooltip_text = text
	
func _ready() -> void:
	mobs = Items.mobs.keys()
	init_spawn_list()

func _on_option_button_item_selected(index: int) -> void:
	print("spawn item selected: " + str(index))
	var text : String = spawn_list.get_item_text(index)
	update_incon(text)
	
