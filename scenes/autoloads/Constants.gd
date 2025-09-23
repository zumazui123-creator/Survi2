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
var INITAL_OBJECTS := 0
var MAX_OBJECTS := 0 #520 #180
var MAX_ENEMIES_PER_PLAYER : int = 2 # 2 # see main.gd for more object and enemy spawner constants
var MAX_ANIMALS_PER_PLAYER : int = 20 
#Player
const MAX_INVENTORY_SLOTS := 12
const OBJECT_SCORE_GAIN := 1
const MOB_SCORE_GAIN := 2
const PK_SCORE_GAIN := 4
# more player related consts are in player.gd
# Item, object and equipment data is in "Items" autoload.
