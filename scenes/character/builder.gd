extends Node
@onready var spawn_list : OptionButton =  $"../CanvasLayer/Code/TabContainerKI/KI Playground/VBoxContainer/SpawnContainer/HBoxContainer/OptionButton"
@onready var spawn_texture : TextureRect =   $"../CanvasLayer/Code/TabContainerKI/KI Playground/VBoxContainer/SpawnContainer/HBoxContainer/TextureRect"
var mobs = ["spider","zombie"]


func get_files_in_folder(path: String) -> Array:
	var files := []
	var dir := DirAccess.open(path)
	if dir == null:
		push_error("Ordner existiert nicht: " + path)
		return files

	dir.list_dir_begin()  # skip_dots = true, skip_hidden = true
	for file in dir.get_files():
		if file.ends_with(".import"):
			var png_file := file.get_basename()
			if png_file.ends_with(".png"):
				files.append(png_file.get_basename())
	return files


func init_spawn_list() -> void:
	for mob in mobs:
		spawn_list.add_item(mob)
		
func update_incon(text : String):
	print("update icon")
	spawn_texture.texture = load("res://assets/characters/enemy/"+text+".png")
	
func _ready() -> void:
	var enemy_folder := "res://assets/characters/enemy/"
	mobs = get_files_in_folder(enemy_folder)
	init_spawn_list()

func _on_option_button_item_selected(index: int) -> void:
	print("spawn item selected: " + str(index))
	var text : String = spawn_list.get_item_text(index)
	update_incon(text)
	
