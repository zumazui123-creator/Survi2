extends Node2D

const ANIMAL_SCENE := preload("res://scenes/animal/animal.tscn")

var animalTypes := Items.animals.keys()
const animalWaveCount := 1
var maxAnimalsPerPlayer :int = Constants.MAX_ANIMALS_PER_PLAYER
const animalSpawnRadiusMin := 2
const animalSpawnRadiusMax := 20
var spawnedAnimals := {}

@onready var navHelper : Node2D = $"../NavHelper"

func _ready() -> void:
	print("ready  Enemies")

#animal spawn
func spawn(position_to_spawn: Vector2) -> Animal:
	print("Spawn")
	var animal := ANIMAL_SCENE.instantiate() as Animal
	animal.position = position_to_spawn
	animal.spawner = self
	animal.actor_id = animalTypes.pick_random()
	return animal 
	
func trySpawnAnimals():
	var players = Multihelper.spawnedPlayers.keys()
	for player in players:
		var playerAnimals := getPlayerAnimalCount(player)
		if playerAnimals < maxAnimalsPerPlayer:
			var toSpawn = min(maxAnimalsPerPlayer - playerAnimals, animalWaveCount)
			var spawnPositions = navHelper.getNRandomNavigableTileInPlayerRadius(
							player, toSpawn, animalSpawnRadiusMin, animalSpawnRadiusMax)
			for pos in spawnPositions:
				var animal := spawn(pos) as Animal
				animal.targetPlayerId = player
				add_child(animal,true)
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
		spawnedAnimals[pId] = maxi(0, spawnedAnimals[pId] - 1)
