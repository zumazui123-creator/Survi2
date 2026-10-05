extends Node2D

var enemyTypes := Items.mobs.keys()
const enemyWaveCount := 1
var maxEnemiesPerPlayer :int = Constants.MAX_ENEMIES_PER_PLAYER
const enemySpawnRadiusMin := 8
const enemySpawnRadiusMax := 29
var spawnedEnemies := {}


@onready var navHelper : Node2D = $"../NavHelper"
@onready var creator : Node = $"../Creator"

func _ready() -> void:
	print("enemies rdy" )

#enemy spawn
func trySpawnEnemies():
	if not multiplayer.is_server() or not GameTime.is_night_time():
		return
	print("SpawnEnemies at hour: "+str( GameTime.get_hour()) )	
	var enemyScene := preload("res://scenes/enemy/enemy.tscn")
	var players = Multihelper.spawnedPlayers.keys()
	for player in players:
		var playerEnemies := getPlayerEnemyCount(player)
		if playerEnemies < maxEnemiesPerPlayer:
			var toSpawn = min(maxEnemiesPerPlayer - playerEnemies, enemyWaveCount)
			var spawnPositions = navHelper.getNRandomNavigableTileInPlayerRadius(
							player, toSpawn, enemySpawnRadiusMin, enemySpawnRadiusMax)
			#print(spawnPositions)				
			for pos in spawnPositions:
				print("add Enemy position:"+str(pos))
				var enemy = enemyScene.instantiate()
				add_child(enemy,true)
				enemy.global_position = pos
				enemy.spawner = self
				enemy.targetPlayerId = player
				enemy.enemyId = enemyTypes.pick_random()
				increasePlayerEnemyCount(player)

func spawn(pos,text):
	if not multiplayer.is_server():
		return null
	var enemyScene := preload("res://scenes/enemy/enemy.tscn")
	print("add Enemy position:"+str(pos))
	var enemy = enemyScene.instantiate()
	add_child(enemy,true)
	enemy.global_position = pos
	enemy.spawner = self
	enemy.targetPlayerId = 1
	enemy.enemyId = text
	return enemy



func getPlayerEnemyCount(pId) -> int:
	if pId in spawnedEnemies:
		return spawnedEnemies[pId]
	return 0

func increasePlayerEnemyCount(pId) -> void:
	if pId in spawnedEnemies:
		spawnedEnemies[pId] += 1
	else:
		spawnedEnemies[pId] = 1

func decreasePlayerEnemyCount(pId) -> void:
	if pId in spawnedEnemies:
		spawnedEnemies[pId] = maxi(0, spawnedEnemies[pId] - 1)
