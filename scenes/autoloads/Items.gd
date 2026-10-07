extends Node

const ITEM_DEFINITIONS: Array[ItemDefinition] = [
	preload("res://assets/data/items/wood.tres"),
	preload("res://assets/data/items/stone.tres"),
	preload("res://assets/data/items/iron.tres"),
	preload("res://assets/data/items/coal.tres"),
	preload("res://assets/data/items/sap.tres"),
	preload("res://assets/data/items/magic_wood.tres"),
	preload("res://assets/data/items/magic_stone.tres"),
	preload("res://assets/data/items/magic_herb.tres"),
	preload("res://assets/data/items/crystal_shard.tres"),
	preload("res://assets/data/items/food.tres"),
	preload("res://assets/data/items/berries.tres"),
	preload("res://assets/data/items/water.tres"),
	preload("res://assets/data/items/energy_drink.tres"),
	preload("res://assets/data/items/torch.tres"),
	preload("res://assets/data/items/sword_1.tres"),
	preload("res://assets/data/items/axe_1.tres"),
	preload("res://assets/data/items/pickaxe_1.tres"),
	preload("res://assets/data/items/spear_1.tres"),
	preload("res://assets/data/items/dagger_1.tres"),
	preload("res://assets/data/items/axe_2.tres"),
	preload("res://assets/data/items/pickaxe_2.tres"),
	preload("res://assets/data/items/magic_sword_1.tres"),
	preload("res://assets/data/items/magic_axe_1.tres"),
	preload("res://assets/data/items/magic_dagger_1.tres"),
	preload("res://assets/data/items/magic_spear_1.tres"),
]

const ENEMY_DEFINITIONS: Array[ActorDefinition] = [
	preload("res://assets/data/enemies/zombie.tres"),
	preload("res://assets/data/enemies/spider.tres"),
]

const ANIMAL_DEFINITIONS: Array[ActorDefinition] = [
	preload("res://assets/data/animals/pig.tres"),
]

const OBJECT_DEFINITIONS: Array[WorldObjectDefinition] = [
	preload("res://assets/data/world_objects/tree_0.tres"),
	preload("res://assets/data/world_objects/tree_1.tres"),
	preload("res://assets/data/world_objects/rock_1.tres"),
	preload("res://assets/data/world_objects/tree_2.tres"),
	preload("res://assets/data/world_objects/rock_2.tres"),
	preload("res://assets/data/world_objects/bush_1.tres"),
	preload("res://assets/data/world_objects/ore_1.tres"),
	preload("res://assets/data/world_objects/tree_3.tres"),
	preload("res://assets/data/world_objects/rock_3.tres"),
	preload("res://assets/data/world_objects/magic_plant_1.tres"),
	preload("res://assets/data/world_objects/crystal_1.tres"),
	preload("res://assets/data/world_objects/magic_tree_1.tres"),
	preload("res://assets/data/world_objects/magic_rock_1.tres"),
	preload("res://assets/data/world_objects/defense_tower.tres"),
]

const PROJECTILE_DEFINITIONS: Array[ProjectileDefinition] = [
	preload("res://assets/data/projectiles/fireshuriken.tres"),
	preload("res://assets/data/projectiles/icebolt.tres"),
	preload("res://assets/data/projectiles/magic_bolt.tres"),
	preload("res://assets/data/projectiles/fireball.tres"),
	preload("res://assets/data/projectiles/ice_shard.tres"),
	preload("res://assets/data/projectiles/lightning_bolt.tres"),
]

# Compatibility indexes keep existing gameplay callers working while content is
# authored as typed resources in assets/data.
var mobs: Dictionary = {}
var animals: Dictionary = {}
var consume: Dictionary = {}
var objects: Dictionary = {}
var equips: Dictionary = {}
var recipes: Dictionary = {}
var projectiles: Dictionary = {}

var item_definitions: Dictionary = {}
var actor_definitions: Dictionary = {}
var object_definitions: Dictionary = {}
var projectile_definitions: Dictionary = {}


func _init() -> void:
	_build_indexes()


func _build_indexes() -> void:
	for definition in ITEM_DEFINITIONS:
		var id: String = String(definition.item_id)
		item_definitions[id] = definition
		match definition.kind:
			ItemDefinition.Kind.CONSUMABLE:
				consume[id] = definition.effects.duplicate(true)
			ItemDefinition.Kind.EQUIPMENT:
				equips[id] = definition.to_legacy_equipment()
		if not definition.recipe.is_empty():
			recipes[id] = definition.recipe.duplicate(true)

	for definition in ENEMY_DEFINITIONS:
		var id: String = String(definition.actor_id)
		actor_definitions[id] = definition
		mobs[id] = definition.to_legacy_dict()

	for definition in ANIMAL_DEFINITIONS:
		var id: String = String(definition.actor_id)
		actor_definitions[id] = definition
		animals[id] = definition.to_legacy_dict()

	for definition in OBJECT_DEFINITIONS:
		var id: String = String(definition.object_id)
		object_definitions[id] = definition
		objects[id] = definition.to_legacy_dict()

	for definition in PROJECTILE_DEFINITIONS:
		var id: String = String(definition.projectile_id)
		projectile_definitions[id] = definition
		projectiles[id] = definition.to_legacy_dict()


func get_item_icon(item_id: String) -> Texture2D:
	var definition: ItemDefinition = item_definitions.get(item_id)
	return definition.icon if definition else null


func get_actor_texture(actor_id: String) -> Texture2D:
	var definition: ActorDefinition = actor_definitions.get(actor_id)
	return definition.texture if definition else null


func get_object_texture(object_id: String) -> Texture2D:
	var definition: WorldObjectDefinition = object_definitions.get(object_id)
	return definition.texture if definition else null


func get_projectile_texture(projectile_id: String) -> Texture2D:
	var definition: ProjectileDefinition = projectile_definitions.get(projectile_id)
	return definition.texture if definition else null


func get_equipment_scene(item_id: String) -> PackedScene:
	var definition: ItemDefinition = item_definitions.get(item_id)
	return definition.equipment_scene if definition else null
