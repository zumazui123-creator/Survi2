extends Control
@onready var enemies = $"../../../Enemies"
@onready var tilemap: TileMapLayer = $"../../../Map/TileMap"
var goal_tile 

func _can_drop_data(at_pos, data) -> bool:
	# Prüfe hier, ob du überhaupt drop erlaubst
	var ok = data in enemies.enemyTypes
	if data == "goal_tile":
		ok = true
	#var cell = get_pos()
	#_spawn_or_highlight(cell, data)
	
	return ok

func _drop_data(at_pos, data) -> void:
	# Wenn gedroppt wird, mach etwas
	var cell = get_pos()
	print("cell pos:"+str(cell))
	 # Spawn oder ändere etwas
	var pos_local = _spawn_or_highlight(cell, data)
	spawn(pos_local, data)

func _spawn_or_highlight(cell: Vector2i, data):
	# Beispiel: Marker auf das Tile setzen
	var pos_local = tilemap.map_to_local(cell)
	return pos_local

func get_pos():
	var inv = tilemap.global_transform.affine_inverse()
	var world_pos = inv * get_global_mouse_position()
	var cell = tilemap.local_to_map(world_pos)
	return cell

func spawn(pos,text):
	if text == "goal_tile":
		if goal_tile:
			tilemap.set_cell(goal_tile,1,Vector2i(0,0),0)
		goal_tile = get_pos()
		tilemap.set_cell(goal_tile,1,Vector2i(23,11),0)
		Multihelper.set_goal(goal_tile)
		
	else:
		enemies.spawn(pos, text)

	
