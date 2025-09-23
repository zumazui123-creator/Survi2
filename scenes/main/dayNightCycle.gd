extends CanvasModulate

const MINUTES_PER_DAY = 1440.0
const MINUTES_PER_HOUR = 60.0
const INGAME_TO_REAL_MINUTE_DURATION = (2 * PI) / MINUTES_PER_DAY


signal time_tick(day:int, hour:int, minute:int)


@export var gradient_texture:GradientTexture1D
@export var INGAME_SPEED = 10.0
@export var INITIAL_HOUR = 18:
	set(h):
		INITIAL_HOUR = h
		time = INGAME_TO_REAL_MINUTE_DURATION * MINUTES_PER_HOUR * INITIAL_HOUR


@export var time:float= 0.0
var past_minute:int= -1
var hour : int = -1

func get_time() -> float:
	return time
	
func get_hour() -> int:
	return hour
	
func isNightTime():
	if get_hour() > 18 || get_hour() < 6:
		return true
	else: 
		return false
		
func _ready() -> void:
	if gradient_texture == null:
		gradient_texture = GradientTexture1D.new()
		var g = Gradient.new()
		g.add_point(0.0, Color(0.0, 0.02, 0.2))     # mitten in der Nacht, fast schwarz/blau
		g.add_point(0.15, Color(0.1, 0.1, 0.5))     # früher Morgen
		g.add_point(0.3, Color(0.4, 0.6, 1.0))      # Morgenlichte blau
		g.add_point(0.45, Color(1.0, 0.9, 0.5))     # Sonnenaufgang gelb
		g.add_point(0.6, Color(1.0, 0.5, 0.0))      # Sonnenuntergang orange
		g.add_point(0.75, Color(0.8, 0.1, 0.1))     # kurz bevor Rot
		g.add_point(0.9, Color(0.2, 0.02, 0.2))     # Abenddämmerung
		g.add_point(1.0, Color(0.0, 0.0, 0.1))      # Nacht
		gradient_texture.gradient = g
		gradient_texture.width = 400
		print("⚠️ No gradient set, using fallback.")
	time = INGAME_TO_REAL_MINUTE_DURATION * MINUTES_PER_HOUR * INITIAL_HOUR


func _process(delta: float) -> void:
	time += delta * INGAME_TO_REAL_MINUTE_DURATION * INGAME_SPEED
	
	#var value = (sin(time - PI / 2.0) + 1.0) / 2.0
	#self.color = gradient_texture.gradient.sample(value)
	
	_recalculate_time()	

		
func _recalculate_time() -> void:
	var total_minutes = int(time / INGAME_TO_REAL_MINUTE_DURATION)
	
	var day = int(total_minutes / MINUTES_PER_DAY)

	var current_day_minutes = total_minutes % int(MINUTES_PER_DAY)

	hour = int(current_day_minutes / MINUTES_PER_HOUR)
	var my_hour = int(current_day_minutes / MINUTES_PER_HOUR)
	var minute = int(current_day_minutes % int(MINUTES_PER_HOUR))
	
	
	var value = (sin(1 - PI / 2.0) + 1.0) / 2.0
	self.color = gradient_texture.gradient.sample(1)
	
	if past_minute != minute:
		past_minute = minute
		#print("hour"+str(my_hour))
		time_tick.emit(day, hour, minute)
