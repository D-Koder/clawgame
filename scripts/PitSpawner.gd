extends Node2D
class_name PitSpawner

@export var ball_types: Array[BallType] = []
@export var config: GameConfig

var ball_scene = preload("res://scenes/Ball.tscn")
var spawned_balls: Array[Ball] = []

func _ready() -> void:
	if not config:
		config = GameConfig.new()
	if ball_types.is_empty():
		_load_default_types()

func _load_default_types() -> void:
	ball_types.append(BallType.new(Color("F1EFE8"), 1, 0.65))
	ball_types.append(BallType.new(Color("D85A30"), 3, 0.06))
	ball_types.append(BallType.new(Color("378ADD"), 3, 0.06))
	ball_types.append(BallType.new(Color("7F77DD"), 5, 0.04))
	ball_types.append(BallType.new(Color("EF9F27"), 4, 0.04))

func pick_type() -> BallType:
	var roll = randf()
	var acc = 0.0
	for t in ball_types:
		acc += t.weight
		if roll <= acc:
			return t
	return ball_types[0]

func spawn_pit() -> Array[Ball]:
	for ball in spawned_balls:
		ball.queue_free()
	spawned_balls.clear()

	var r = config.ball_radius
	var row = 0
	var y = config.floor_y - r
	while y > 200.0:
		var offset = 0.0 if row % 2 == 0 else r
		var x = config.wall_left + r + offset
		while x < config.wall_right - r:
			var ball = ball_scene.instantiate() as Ball
			var pos = Vector2(x + randf_range(-1.0, 1.0), y + randf_range(-1.0, 1.0))
			ball.position = pos
			ball.ball_type = pick_type()
			ball.config = config
			add_child(ball)
			spawned_balls.append(ball)
			x += r * 2.0
		y -= r * 1.6
		row += 1

	return spawned_balls

func get_balls() -> Array[Ball]:
	return spawned_balls

func clear_pit() -> void:
	for ball in spawned_balls:
		ball.queue_free()
	spawned_balls.clear()
