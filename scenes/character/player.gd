extends CharacterBody2D


var act : String = ""

@export var status: PlayerStats
@export var status_view: PlayerStatusView
@export var ai_control : Node
var workTaskText: RichTextLabel
@export var net_control : Node 
@export var movement: PlayerMovement
@export var animation: PlayerAnimationController
@export var combat: PlayerCombat
@export var building: PlayerBuilding
@export var items: PlayerItems
@export var code_player: CodePlayer
@export var goal_tracker: PlayerGoalTracker
@export var sensor: PlayerSensor
@export var environment: Survi2NavigationEnv
@export var rl_agent: RLAgent
@export var rl_trainer: RLTrainer
var code_edit: CodeEdit
var local_ui: PlayerLocalUI
@export var playerName : String:
	set(value):
		playerName = value
		if status_view:
			status_view.set_player_name(value)

var characterFile : String:
	set(value):
		characterFile = value
		if is_node_ready() and characterFile != "":
			animation.set_character_sprite(characterFile)

var EndUI     : Control
var local_setup_done := false
@onready var world_map: Map = get_tree().get_first_node_in_group("world_map")

func _enter_tree():
	set_multiplayer_authority(name.to_int())

func _ready():
	var line = Line2D.new()
	line.name = "PathLine"
	line.default_color = Color(1, 1, 1, 0.3)
	line.width = 2
	line.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
	line.z_index = -1 # Draw behind other elements
	add_child(line)
	movement.path_line = line
	goal_tracker.goal_reached.connect(_on_goal_reached)
	status.leveled_up.connect(_on_level_up)
	
	Multihelper.data_loaded.connect(_on_multidata_received)
	Multihelper.player_spawned.connect(_on_player_spawned_info)
	Multihelper.player_disconnected.connect(disconnected)
	
	if characterFile == "":
		try_recover_body()
	else:
		_setup_local_player()
				
	if characterFile != "":
		animation.set_character_sprite(characterFile)


func _on_multidata_received():
	try_recover_body()

func _on_player_spawned_info(id, info):
	if str(id) == name:
		try_recover_body()

func try_recover_body():
	var pid = name.to_int()
	if not Multihelper.spawnedPlayers.has(pid):
		return
		
	var info = Multihelper.spawnedPlayers[pid]
	
	if playerName == "" and info.has("name"):
		self.playerName = info["name"]
		
	if characterFile == "" and info.has("body"):
		print("Recovered body from Multihelper: " + str(info["body"]))
		self.characterFile = info["body"]
		#var p_combat_node = get_node("PlayerCombat")
		#if p_combat_node:
			#Inventory.itemRemoved.connect(p_items.itemRemoved)
			#p_combat_node.mob_killed.connect(p_combat_node.mobKilled)
			#p_combat_node.player_killed.connect(p_combat_node.enemyPlayerKilled)
			#p_combat_node.object_destroyed.connect(p_combat_node.objectDestroyed)
	
	_setup_local_player()

func _setup_local_player():
	if local_setup_done or not is_multiplayer_authority():
		return
	local_setup_done = true
	print("player HUD")
	EndUI = get_tree().get_first_node_in_group("end_ui")
	var hud := get_tree().get_first_node_in_group("world_hud")
	var local_ui_scene := preload("res://scenes/ui/player_workspace/player_local_ui.tscn")
	local_ui = local_ui_scene.instantiate()
	hud.add_child(local_ui)
	local_ui.bind_player(self)
	$Camera2D.enabled = true

@rpc("any_peer", "call_local", "reliable")
func getDamage(causer: Node, amount: float, damage_type: StringName) -> void:
	combat.getDamage(causer, amount, damage_type)
		
func visibilityFilter(id):
	if id == int(str(name)):
		return false
	return true

@rpc("any_peer", "call_local", "reliable")
func sendMessage(text):
	#if multiplayer.is_server():
		var messageBoxScene := preload(Constants.PATH_CHAT_MESSAGE_SCENE)
		var messageBox := messageBoxScene.instantiate()
		%PlayerMessages.add_child(messageBox, true)
		messageBox.text = str(text)

func disconnected(id):
	if str(id) == name:
		combat.die()


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	movement.input()
	movement.tile_move(delta)


func _on_goal_reached() -> void:
	if not is_instance_valid(EndUI):
		EndUI = get_tree().get_first_node_in_group("end_ui")
	if not is_instance_valid(EndUI):
		return
	EndUI.setLabel("Level Abgeschlossen!")
	EndUI.visible = true


func _on_level_up(new_level: int) -> void:
	animation.play_level_up_animation(new_level)


func set_rl_agent(value: RLAgent) -> bool:
	if not is_instance_valid(rl_trainer) or not rl_trainer.set_agent(value):
		return false
	rl_agent = value
	return true
			
func resetPlayer():
	var difLevelMode = local_ui.get_difficulty_mode() if is_instance_valid(local_ui) else 0
	if difLevelMode > 0:
		Multihelper.spawnPlayers()


@rpc("any_peer", "call_local", "reliable")
func sendPos(pos):
	position = pos
	movement.synchronize_to_player_position(true)


func _exit_tree() -> void:
	if is_instance_valid(local_ui):
		local_ui.queue_free()
	
