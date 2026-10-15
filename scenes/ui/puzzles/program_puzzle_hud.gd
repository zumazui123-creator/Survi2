extends PanelContainer
class_name ProgramPuzzleHUD

@onready var title_label: Label = %TitleLabel
@onready var message_label: Label = %MessageLabel
@onready var progress_label: Label = %ProgressLabel
@onready var time_label: Label = %TimeLabel
@onready var hide_timer: Timer = %HideTimer

var _fade_tween: Tween


func _ready() -> void:
	hide()
	hide_timer.timeout.connect(_fade_out)


func present(
		title: String,
		message: String,
		status: String,
		time_text: String,
		tone: int,
		hide_after_seconds: float = 0.0
	) -> void:
	_show_panel(title, _get_tone_color(tone))
	message_label.text = message
	progress_label.text = status
	time_label.text = time_text
	if hide_after_seconds > 0.0:
		hide_timer.start(hide_after_seconds)
	else:
		hide_timer.stop()


func hide_immediately() -> void:
	hide_timer.stop()
	if is_instance_valid(_fade_tween):
		_fade_tween.kill()
	hide()


func _show_panel(title: String, accent: Color) -> void:
	if is_instance_valid(_fade_tween):
		_fade_tween.kill()
	title_label.text = title
	title_label.add_theme_color_override("font_color", accent)
	modulate.a = 1.0
	show()


func _get_tone_color(tone: int) -> Color:
	match tone:
		1:
			return Color(0.45, 1.0, 0.72, 1.0)
		2:
			return Color(1.0, 0.82, 0.25, 1.0)
		3:
			return Color(1.0, 0.32, 0.26, 1.0)
		_:
			return Color(0.55, 0.9, 1.0, 1.0)


func _fade_out() -> void:
	if is_instance_valid(_fade_tween):
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, 0.3)
	_fade_tween.tween_callback(hide)
