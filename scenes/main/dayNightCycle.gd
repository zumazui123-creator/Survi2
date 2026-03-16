extends CanvasModulate

# --------------------
# KONSTANTEN
# --------------------
const MINUTES_PER_DAY : int = 1440
const MINUTES_PER_HOUR : int = 60
const TIME_TO_RAD := (2.0 * PI) / MINUTES_PER_DAY

# --------------------
# SIGNALS
# --------------------
signal time_tick(day: int, hour: int, minute: int)

# --------------------
# EXPORTS
# --------------------
@export var gradient_texture: GradientTexture1D
@export var ingame_speed := 4.0
@export var initial_hour := 13.3:
	set(value):
		initial_hour = value
		time = value * MINUTES_PER_HOUR * TIME_TO_RAD

# --------------------
# STATE
# --------------------
@export var time := 0.0
var past_minute := -1
var hour := 0

# --------------------
# GETTER
# --------------------
func get_hour() -> int:
	return hour

func is_night_time() -> bool:
	# sehr kurze Nacht: 23:00 – 04:00
	return hour >= 23 or hour < 1

# --------------------
# READY
# --------------------
func _ready() -> void:
	if gradient_texture == null:
		_create_fallback_gradient()

	time = initial_hour * MINUTES_PER_HOUR * TIME_TO_RAD

# --------------------
# PROCESS
# --------------------
func _process(delta: float) -> void:
	time += delta * TIME_TO_RAD * ingame_speed
	_update_color()
	_update_clock()

# --------------------
# COLOR
# --------------------
func _update_color() -> void:
	var day_value := _compressed_day_curve()
	color = gradient_texture.gradient.sample(day_value)

# Nacht bewusst stark komprimiert
func _compressed_day_curve() -> float:
	var raw := (sin(time - PI / 2.0) + 1.0) * 0.5

	if raw < 0.08:
		return raw * 0.3       # sehr kurze Nacht
	return 0.08 + (raw - 0.08) * 1.05

# --------------------
# TIME
# --------------------
func _update_clock() -> void:
	var total_minutes := int(time / TIME_TO_RAD)
	var day := int(total_minutes / MINUTES_PER_DAY)

	var day_minutes = total_minutes % int(MINUTES_PER_DAY)
	hour = int(day_minutes / MINUTES_PER_HOUR)
	var minute := int(day_minutes % MINUTES_PER_HOUR)

	if minute != past_minute:
		past_minute = minute
		time_tick.emit(day, hour, minute)

# --------------------
# GRADIENT
# --------------------
func _create_fallback_gradient() -> void:
	gradient_texture = GradientTexture1D.new()
	var g := Gradient.new()

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
