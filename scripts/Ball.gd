extends RigidBody2D
class_name Ball

@export var ball_type: BallType
var config: GameConfig

func _ready() -> void:
	config = GameConfig.new() if not config else config
	if ball_type:
		_setup_visuals()

func _setup_visuals() -> void:
	var visual = $Visual as ColorRect
	if visual:
		visual.color = ball_type.color
		visual.custom_minimum_size = Vector2(config.ball_radius * 2, config.ball_radius * 2)
		
func set_ball_type(type: BallType) -> void:
	ball_type = type
	_setup_visuals()

func set_config(cfg: GameConfig) -> void:
	config = cfg
	if ball_type:
		_setup_visuals()
