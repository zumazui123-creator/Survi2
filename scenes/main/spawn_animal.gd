extends Node2D

var animalTypes := Items.animals.keys()
const animalWaveCount := 1
var maxAnimalsPerPlayer :int = Constants.MAX_ANIMALS_PER_PLAYER
const animalSpawnRadiusMin := 2
const animalSpawnRadiusMax := 20
var spawnedAnimals := {}

@onready var navHelper : Node2D = $"../NavHelper"

#animal spawn
func trySpawnAnimals():
	var animalScene := preload("res://scenes/animal/animal.tscn")
	var players = Multihelper.spawnedPlayers.keys()
	for player in players:
		var playerAnimals := getPlayerAnimalCount(player)
		if playerAnimals < maxAnimalsPerPlayer:
			var toSpawn = min(maxAnimalsPerPlayer - playerAnimals, animalWaveCount)
			var spawnPositions = navHelper.getNRandomNavigableTileInPlayerRadius(
							player, toSpawn, animalSpawnRadiusMin, animalSpawnRadiusMax)
			for pos in spawnPositions:
				var animal = animalScene.instantiate()
				add_child(animal,true)
				animal.position = pos
				animal.spawner = self
				animal.targetPlayerId = player
				animal.animalId = animalTypes.pick_random()
				increasePlayerAnimalCount(player)

func getPlayerAnimalCount(pId) -> int:
	if pId in spawnedAnimals:
		return spawnedAnimals[pId]
	return 0

func increasePlayerAnimalCount(pId) -> void:
	if pId in spawnedAnimals:
		spawnedAnimals[pId] += 1
	else:
		spawnedAnimals[pId] = 1

func decreasePlayerAnimalCount(pId) -> void:
	if pId in spawnedAnimals:
		spawnedAnimals[pId] -= 1
	else:
		spawnedAnimals[pId] = 1
