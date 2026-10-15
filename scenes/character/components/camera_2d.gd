extends Camera2D

var _shake_strength: float = 0.0
var _shake_remaining: float = 0.0
var _shake_duration: float = 0.0
var _shake_rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_shake_rng.randomize()


func _process(delta: float) -> void:
	if _shake_remaining <= 0.0:
		offset = Vector2.ZERO
		return
	_shake_remaining = maxf(_shake_remaining - delta, 0.0)
	var fade: float = _shake_remaining / maxf(_shake_duration, 0.001)
	offset = Vector2(
		_shake_rng.randf_range(-1.0, 1.0),
		_shake_rng.randf_range(-1.0, 1.0)
	) * _shake_strength * fade


func shake(strength: float, duration: float) -> void:
	_shake_strength = maxf(strength, 0.0)
	_shake_duration = maxf(duration, 0.0)
	_shake_remaining = _shake_duration
