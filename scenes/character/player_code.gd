extends Node

func press_action(inp_action : String):
	if inp_action == "":
		return
	inp_action = inp_action.strip_edges()

	if Strings.ACTION_SAY in inp_action:
		print("sage:"+inp_action)
		var text = inp_action.trim_prefix(Strings.ACTION_SAY)
	

	#if Strings.ACTION_USE_ITEM in inp_action:
		#var item_id = player_items.use_item(inp_action)

	#player_movement.press_action(inp_action)
	
	if Multihelper.level in range(0,2) and "End Sequenz" in inp_action:
		#code_edit.text = ""
		var end = Multihelper.map.laby_map.spawnPosition
		var start = Multihelper.map.tile_map.map_to_local( end )
		#position = start
