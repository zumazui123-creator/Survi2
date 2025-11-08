extends Node

#Multiplayer
const SERVER_IP := "localhost"
const PORT := 3131
const USE_SSL := false # put certs in assets/certs, a free let's encrypt one works for itch.io
const TRUSTED_CHAIN_PATH := ""
const PRIVATE_KEY_PATH := ""

#Map
#const MAP_SIZE := Vector2i(128,128) # see map.gd for tileset specific constants
const MAP_SIZE := Vector2i(256,256)
const TILE_SIZE: int = 32
var INITAL_OBJECTS := 0
var MAX_OBJECTS := 520 #180
var MAX_ENEMIES_PER_PLAYER : int = 2 # 2 # see main.gd for more object and enemy spawner constants
var MAX_ANIMALS_PER_PLAYER : int = 20

# --- Map  Types ---
const MAP_MAIN : int = 1
const MAP_LABY  : int = 2
const MAP_TOURMENT : int = 3


#Player
const MAX_INVENTORY_SLOTS := 12
const OBJECT_SCORE_GAIN := 1
const MOB_SCORE_GAIN := 2
const PK_SCORE_GAIN := 4

# --- File Paths ---
const PATH_CHARACTER_BODIES = "res://assets/characters/bodies/"
const PATH_ITEMS = "res://assets/items/"
const PATH_EQUIPMENT_SCENES = "res://scenes/character/equipments/"
const PATH_CHAT_MESSAGE_SCENE = "res://scenes/ui/chat/message_box.tscn"
const PATH_GAME_SCENE = "res://scenes/game/Game.tscn"
const PATH_PICKUP_SCENE = "res://scenes/item/pickup.tscn"
const PATH_PROJECTILE_ATTACK_SCENE = "res://scenes/attacks/projectile_attack.tscn"
