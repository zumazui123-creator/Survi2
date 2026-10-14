extends WanderingMerchant
class_name CaravanMerchant

signal caravan_route_finished(caravan: CaravanMerchant, destination_tile: Vector2i)

@export_range(10.0, 300.0, 1.0) var caravan_speed: float = 55.0

@onready var route_follower: WorldEventRouteFollower = $RouteFollower


func _ready() -> void:
	external_navigation_enabled = true
	super()
	route_follower.movement_speed = caravan_speed
	if not route_follower.route_finished.is_connected(_on_route_finished):
		route_follower.route_finished.connect(_on_route_finished)


func travel_to(
		world_map: Map,
		navigation_graph: WorldEventNavigationGraph,
		destination_tile: Vector2i,
		start_delay: float = 0.0
	) -> void:
	route_follower.configure_route(
		self,
		world_map,
		navigation_graph,
		destination_tile,
		start_delay
	)


func _on_route_finished(destination_tile: Vector2i) -> void:
	caravan_route_finished.emit(self, destination_tile)
