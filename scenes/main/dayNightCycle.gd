extends CanvasModulate

# --------------------
# KONSTANTEN
# --------------------
const MINUTES_PER_DAY : int = 1440
const MINUTES_PER_HOUR : int = 60
const TIME_TO_RAD: float = (2.0 * PI) / MINUTES_PER_DAY

# --------------------
# SIGNALS
# --------------------
signal time_tick(day: int, hour: int, minute: int)

# --------------------
# EXPORTS
# --------------------
@export var gradient_texture: GradientTexture1D
@export var ingame_speed: float = 4.0
@export var initial_hour: float = 13.3:
	set(value):
		initial_hour = value
		time = value * MINUTES_PER_HOUR * TIME_TO_RAD
@export var cycle_enabled: bool = true
@export_range(0.0, 23.99, 0.1) var disabled_hour: float = 13.3

# --------------------
# STATE
# --------------------
@export var time: float = 0.0
var past_minute: int = -1
var hour: int = 0

# --------------------
# GETTER
# --------------------
func get_hour() -> int:
	return hour

func is_night_time() -> bool:
	if not cycle_enabled:
		return false
	# sehr kurze Nacht: 23:00 – 04:00
	return hour >= 23 or hour < 1


func set_cycle_enabled(enabled: bool) -> void:
	cycle_enabled = enabled
	past_minute = -1
	var target_hour: float = initial_hour if cycle_enabled else disabled_hour
	time = target_hour * MINUTES_PER_HOUR * TIME_TO_RAD
	_update_color()
	_update_clock()

# --------------------
# READY
# --------------------
func _ready() -> void:
	if gradient_texture == null:
		_create_fallback_gradient()

	time = initial_hour * MINUTES_PER_HOUR * TIME_TO_RAD
	set_cycle_enabled(cycle_enabled)

# --------------------
# PROCESS
# --------------------
func _process(delta: float) -> void:
	if not cycle_enabled:
		return
	time += delta * TIME_TO_RAD * ingame_speed
	_update_color()
	_update_clock()

# --------------------
# COLOR
# --------------------
func _update_color() -> void:
	if not cycle_enabled:
		color = Color.WHITE
		return
	var day_value: float = _compressed_day_curve()
	color = gradient_texture.gradient.sample(day_value)

# Nacht bewusst stark komprimiert
func _compressed_day_curve() -> float:
	var raw: float = (sin(time - PI / 2.0) + 1.0) * 0.5

	if raw < 0.08:
		return raw * 0.3       # sehr kurze Nacht
	return 0.08 + (raw - 0.08) * 1.05

# --------------------
# TIME
# --------------------
func _update_clock() -> void:
	var total_minutes: int = int(time / TIME_TO_RAD)
	var day: int = int(total_minutes / MINUTES_PER_DAY)

	var day_minutes: int = total_minutes % int(MINUTES_PER_DAY)
	hour = int(day_minutes / MINUTES_PER_HOUR)
	var minute: int = int(day_minutes % MINUTES_PER_HOUR)

	if minute != past_minute:
		past_minute = minute
		time_tick.emit(day, hour, minute)

# --------------------
# GRADIENT
# --------------------
func _create_fallback_gradient() -> void:
	gradient_texture = GradientTexture1D.new()
	var g: Gradient = Gradient.new()

	# KURZE NACHT
	g.add_point(0.0, Color(0.3, 0.5, 0.5))   # Nacht morgen
	g.add_point(0.08, Color(0.4, 0.6, 0.8))  # früher Morgen
	g.add_point(0.25, Color(1.0, 0.9, 0.6))   # Morgen
	g.add_point(0.45, Color(1.0, 0.9, 0.6))   # Sonnenaufgang
	g.add_point(0.75, Color(1.0, 1.0, 1.0))   # Mittag
	g.add_point(0.9, Color(1.0, 0.7, 0.6))    # Sonnenuntergang
	g.add_point(1.0, Color(0.0, 0.0, 0.25))   # Nacht

	gradient_texture.gradient = g
	gradient_texture.width = 512

	print("⚠️ No gradient assigned – fallback gradient created.")
