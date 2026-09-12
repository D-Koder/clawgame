extends Resource
class_name BallType

@export var color: Color
@export var value: int
@export var weight: float

func _init(p_color: Color = Color.WHITE, p_value: int = 1, p_weight: float = 0.25) -> void:
	color = p_color
	value = p_value
	weight = p_weight
