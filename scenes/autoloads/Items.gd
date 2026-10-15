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
	preload("res://assets/data/items/cooked_food.tres"),
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
	preload("res://assets/data/items/golem_core.tres"),
	preload("res://assets/data/items/forest_core.tres"),
	preload("res://assets/data/items/forest_stew.tres"),
	preload("res://assets/data/items/ice_crystal.tres"),
	preload("res://assets/data/items/frost_sword_1.tres"),
	preload("res://assets/data/items/ancient_technology.tres"),
	preload("res://assets/data/items/gold.tres"),
	preload("res://assets/data/items/treasure_map.tres"),
	preload("res://assets/data/items/magic_artifact.tres"),
	preload("res://assets/data/items/rare_blueprint.tres"),
	preload("res://assets/data/items/ghost_essence.tres"),
	preload("res://assets/data/items/contraband.tres"),
	preload("res://assets/data/items/potion_recipe.tres"),
	preload("res://assets/data/items/ancient_tool.tres"),
	preload("res://assets/data/items/legendary_ice.tres"),
	preload("res://assets/data/items/spirit_potion.tres"),
]

const ENEMY_DEFINITIONS: Array[ActorDefinition] = [
	preload("res://assets/data/enemies/zombie.tres"),
	preload("res://assets/data/enemies/spider.tres"),
]

const ANIMAL_DEFINITIONS: Array[ActorDefinition] = [
	preload("res://assets/data/animals/pig.tres"),
]

const NPC_DEFINITIONS: Array[ActorDefinition] = [
	preload("res://assets/data/actors/villager.tres"),
	preload("res://assets/data/actors/bandit.tres"),
	preload("res://assets/data/actors/stone_golem.tres"),
	preload("res://assets/data/actors/stone_minion.tres"),
	preload("res://assets/data/actors/forest_colossus.tres"),
	preload("res://assets/data/actors/forest_sapling.tres"),
	preload("res://assets/data/actors/forest_spirit.tres"),
	preload("res://assets/data/actors/swamp_ghost.tres"),
	preload("res://assets/data/actors/arcane_sentinel.tres"),
	preload("res://assets/data/actors/mechanical_guardian.tres"),
	preload("res://assets/data/actors/sand_monster.tres"),
	preload("res://assets/data/actors/ice_creature.tres"),
	preload("res://assets/data/actors/swamp_crawler.tres"),
	preload("res://assets/data/actors/frost_giant.tres"),
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
	preload("res://assets/data/world_objects/tree_4.tres"),
	preload("res://assets/data/world_objects/tree_5.tres"),
	preload("res://assets/data/world_objects/tree_6.tres"),
	preload("res://assets/data/world_objects/rock_3.tres"),
	preload("res://assets/data/world_objects/magic_plant_1.tres"),
	preload("res://assets/data/world_objects/crystal_1.tres"),
	preload("res://assets/data/world_objects/magic_tree_1.tres"),
	preload("res://assets/data/world_objects/magic_rock_1.tres"),
	preload("res://assets/data/world_objects/ice_crystal_1.tres"),
]

const PROJECTILE_DEFINITIONS: Array[ProjectileDefinition] = [
	preload("res://assets/data/projectiles/cannonball.tres"),
	preload("res://assets/data/projectiles/magic_pulse.tres"),
	preload("res://assets/data/projectiles/fireshuriken.tres"),
	preload("res://assets/data/projectiles/icebolt.tres"),
	preload("res://assets/data/projectiles/magic_bolt.tres"),
	preload("res://assets/data/projectiles/fireball.tres"),
	preload("res://assets/data/projectiles/ice_shard.tres"),
	preload("res://assets/data/projectiles/lightning_bolt.tres"),
	preload("res://assets/data/projectiles/golem_rock.tres"),
	preload("res://assets/data/projectiles/forest_log.tres"),
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
	for resource: Resource in ITEM_DEFINITIONS:
		var definition: ItemDefinition = resource as ItemDefinition
		if definition == null:
			_report_invalid_definition(resource, &"ItemDefinition")
			continue
		var id: String = String(definition.item_id)
		if id.is_empty():
			_report_missing_id(resource, &"item_id")
			continue
		item_definitions[id] = definition
		match definition.kind:
			ItemDefinition.Kind.CONSUMABLE:
				consume[id] = definition.effects.duplicate(true)
			ItemDefinition.Kind.EQUIPMENT:
				equips[id] = definition.to_legacy_equipment()
		if not definition.recipe.is_empty():
			recipes[id] = definition.recipe.duplicate(true)

	for resource: Resource in ENEMY_DEFINITIONS:
		var definition: ActorDefinition = resource as ActorDefinition
		if definition == null:
			_report_invalid_definition(resource, &"ActorDefinition")
			continue
		var id: String = String(definition.actor_id)
		if id.is_empty():
			_report_missing_id(resource, &"actor_id")
			continue
		actor_definitions[id] = definition
		mobs[id] = definition.to_legacy_dict()

	for resource: Resource in ANIMAL_DEFINITIONS:
		var definition: ActorDefinition = resource as ActorDefinition
		if definition == null:
			_report_invalid_definition(resource, &"ActorDefinition")
			continue
		var id: String = String(definition.actor_id)
		if id.is_empty():
			_report_missing_id(resource, &"actor_id")
			continue
		actor_definitions[id] = definition
		animals[id] = definition.to_legacy_dict()

	# NPC definitions are addressable by Creature without entering the random
	# enemy or animal spawn pools.
	for resource: Resource in NPC_DEFINITIONS:
		var definition: ActorDefinition = resource as ActorDefinition
		if definition == null:
			_report_invalid_definition(resource, &"ActorDefinition")
			continue
		var id: String = String(definition.actor_id)
		if id.is_empty():
			_report_missing_id(resource, &"actor_id")
			continue
		actor_definitions[id] = definition

	for resource: Resource in OBJECT_DEFINITIONS:
		var definition: WorldObjectDefinition = resource as WorldObjectDefinition
		if definition == null:
			_report_invalid_definition(resource, &"WorldObjectDefinition")
			continue
		var id: String = String(definition.object_id)
		if id.is_empty():
			_report_missing_id(resource, &"object_id")
			continue
		object_definitions[id] = definition
		objects[id] = definition.to_legacy_dict()

	for resource: Resource in PROJECTILE_DEFINITIONS:
		var definition: ProjectileDefinition = resource as ProjectileDefinition
		if definition == null:
			_report_invalid_definition(resource, &"ProjectileDefinition")
			continue
		var id: String = String(definition.projectile_id)
		if id.is_empty():
			_report_missing_id(resource, &"projectile_id")
			continue
		projectile_definitions[id] = definition
		projectiles[id] = definition.to_legacy_dict()


func _report_invalid_definition(resource: Resource, expected_type: StringName) -> void:
	var path: String = resource.resource_path if resource != null else "<null>"
	var actual_type: String = resource.get_class() if resource != null else "null"
	push_error(
		"Items: '%s' was loaded as %s instead of %s. Check the resource's script."
		% [path, actual_type, expected_type]
	)


func _report_missing_id(resource: Resource, property_name: StringName) -> void:
	var path: String = resource.resource_path if resource != null else "<null>"
	push_error("Items: '%s' has no %s." % [path, property_name])


func get_item_icon(item_id: String) -> Texture2D:
	var definition: ItemDefinition = item_definitions.get(item_id)
	return definition.icon if definition else null


func get_item_recipe(item_id: String) -> Dictionary:
	var definition: ItemDefinition = item_definitions.get(item_id) as ItemDefinition
	if definition != null and not definition.recipe.is_empty():
		return definition.recipe
	return {}


func get_craftable_item_ids() -> PackedStringArray:
	var craftable_ids: PackedStringArray = PackedStringArray()
	for definition: ItemDefinition in ITEM_DEFINITIONS:
		if definition == null \
				or definition.item_id.is_empty() \
				or definition.recipe.is_empty():
			continue
		craftable_ids.append(String(definition.item_id))
	craftable_ids.sort()
	return craftable_ids


func get_actor_texture(actor_id: String) -> Texture2D:
	var definition: ActorDefinition = actor_definitions.get(actor_id)
	return definition.texture if definition else null


func get_object_texture(object_id: String) -> Texture2D:
	var definition: WorldObjectDefinition = get_object_definition(object_id)
	return definition.texture if definition else null


func get_object_definition(object_id: String) -> WorldObjectDefinition:
	return object_definitions.get(object_id) as WorldObjectDefinition


func get_projectile_texture(projectile_id: String) -> Texture2D:
	var definition: ProjectileDefinition = projectile_definitions.get(projectile_id)
	return definition.texture if definition else null


func get_equipment_scene(item_id: String) -> PackedScene:
	var definition: ItemDefinition = item_definitions.get(item_id)
	return definition.equipment_scene if definition else null
