extends Node

@onready var funcList = %FuncList


func set_func(packets : String):
	print("set func:"+packets)
	if packets.length() < 1:
		return "Wrong"
	
