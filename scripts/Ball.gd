extends RigidBody2D
class_name Ball

@export var ball_type: BallType
var config: GameConfig

func _ready() -> void:
	config = GameConfig.new() if not config else config
	if ball_type:
		_setup_visuals()

func _setup_visuals() -> void:
	var sprite = $Sprite2D as Sprite2D
	if sprite:
		sprite.modulate = ball_type.color
		sprite.scale = Vector2(config.ball_radius, config.ball_radius) / 8.0

func set_ball_type(type: BallType) -> void:
	ball_type = type
	_setup_visuals()

func set_config(cfg: GameConfig) -> void:
	config = cfg
	if ball_type:
		_setup_visuals()
