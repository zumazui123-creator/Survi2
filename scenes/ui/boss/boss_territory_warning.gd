extends PanelContainer
class_name BossTerritoryWarning

@export_range(1.0, 12.0, 0.25) var display_seconds: float = 5.0

@onready var title_label: Label = %TitleLabel
@onready var message_label: Label = %MessageLabel
@onready var display_timer: Timer = %DisplayTimer

var _fade_tween: Tween


func _ready() -> void:
	hide()
	display_timer.timeout.connect(_fade_out)


func show_warning(title: String, message: String, accent: Color) -> void:
	if is_instance_valid(_fade_tween):
		_fade_tween.kill()
	title_label.text = title
	title_label.add_theme_color_override("font_color", accent)
	message_label.text = message
	modulate.a = 0.0
	show()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0, 0.2)
	display_timer.start(display_seconds)


func hide_warning() -> void:
	display_timer.stop()
	if is_instance_valid(_fade_tween):
		_fade_tween.kill()
	hide()


func _fade_out() -> void:
	if is_instance_valid(_fade_tween):
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, 0.35)
	_fade_tween.tween_callback(hide)
