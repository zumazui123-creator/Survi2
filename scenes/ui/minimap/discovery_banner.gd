extends PanelContainer
class_name DiscoveryBanner

@export_range(1.0, 10.0, 0.25) var display_duration: float = 4.0

@onready var message_label: Label = $DiscoveryText
@onready var display_timer: Timer = $DisplayTimer

var _exploration_tracker: MapExplorationTracker
var _notification_queue: Array[Dictionary] = []


func _ready() -> void:
	visible = false
	display_timer.one_shot = true
	display_timer.timeout.connect(_on_display_timer_timeout)
	_exploration_tracker = get_tree().get_first_node_in_group(
		"map_exploration_tracker"
	) as MapExplorationTracker
	if is_instance_valid(_exploration_tracker):
		_exploration_tracker.location_discovered.connect(_on_location_discovered)
		_exploration_tracker.exploration_reset.connect(_on_exploration_reset)


func _on_location_discovered(location_name: String, description: String) -> void:
	_notification_queue.append({
		"name": location_name,
		"description": description,
	})
	_show_next_notification()


func _show_next_notification() -> void:
	if visible or _notification_queue.is_empty():
		return
	var notification: Dictionary = _notification_queue.pop_front()
	var location_name: String = String(notification.get("name", "Unbekannter Ort"))
	var description: String = String(notification.get("description", ""))
	message_label.text = "Neuer Ort entdeckt: %s" % location_name
	if not description.is_empty():
		message_label.text += "\n%s" % description
	visible = true
	display_timer.start(display_duration)


func _on_display_timer_timeout() -> void:
	visible = false
	_show_next_notification()


func _on_exploration_reset() -> void:
	_notification_queue.clear()
	display_timer.stop()
	visible = false
