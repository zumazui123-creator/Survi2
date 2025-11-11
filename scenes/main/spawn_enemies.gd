extends Node2D

var enemyTypes := Items.mobs.keys()
const enemyWaveCount := 1
var maxEnemiesPerPlayer :int = Constants.MAX_ENEMIES_PER_PLAYER
const enemySpawnRadiusMin := 8
const enemySpawnRadiusMax := 29
var spawnedEnemies := {}


@onready var navHelper : Node2D = $"../NavHelper"


func _ready() -> void:
	pass

#enemy spawn
func trySpawnEnemies():
	if not GameTime.isNightTime():
		return
	#print("SpawnEnemies at hour: "+str( GameTime.get_hour()) )	
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
				enemy.position = pos
				enemy.spawner = self
				enemy.targetPlayerId = player
				enemy.enemyId = enemyTypes.pick_random()
				increasePlayerEnemyCount(player)
		
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
		spawnedEnemies[pId] -= 1
	else:
		spawnedEnemies[pId] = 1
