extends Node

const MAIN_TEMPLATE: LevelDefinition = preload("res://assets/data/levels/main_0.tres")
const LABYRINTH_TEMPLATE: LevelDefinition = preload("res://assets/data/levels/labyrinth_0.tres")
const TOURNAMENT_TEMPLATE: LevelDefinition = preload("res://assets/data/levels/tournament_0.tres")
const AI_TEMPLATE: LevelDefinition = preload("res://assets/data/levels/ai_0.tres")

const MAX_MAIN_LEVEL := 2
const MAX_LABYRINTH_LEVEL := 50
const MAX_TOURNAMENT_LEVEL := 5

var MainLevels: Dictionary = {}
var LabyrinthLevels: Dictionary = {}
var TurnierLevels: Dictionary = {}
var KiLevels: Dictionary = {}


func _init() -> void:
	MainLevels = _build_levels(MAIN_TEMPLATE, MAX_MAIN_LEVEL)
	LabyrinthLevels = _build_levels(LABYRINTH_TEMPLATE, MAX_LABYRINTH_LEVEL)
	TurnierLevels = _build_levels(TOURNAMENT_TEMPLATE, MAX_TOURNAMENT_LEVEL)
	KiLevels = _build_levels(AI_TEMPLATE, 0)


func _build_levels(template: LevelDefinition, maximum_level: int) -> Dictionary:
	var result := {}
	for level_number in range(maximum_level + 1):
		var data := template.to_dict()
		data["level"] = level_number
		result[level_number] = data
	return result
