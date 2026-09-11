extends Resource
class_name GameConfig

@export var canvas_width: float = 340.0
@export var canvas_height: float = 400.0
@export var wall_left: float = 20.0
@export var wall_right: float = 320.0
@export var floor_y: float = 390.0

@export var rest_y: float = 35.0
@export var max_drop_y: float = 320.0
@export var drop_speed: float = 200.0
@export var rise_speed: float = 240.0
@export var dig_time: float = 0.6

@export var push_radius: float = 32.0
@export var catch_radius: float = 55.0
@export var push_factor: float = 0.05
@export var max_grab: int = 12

@export var gravity: float = 700.0
@export var damping: float = 0.94

@export var min_x: float = 40.0
@export var max_x: float = 300.0

@export var ball_radius: float = 12.0

var dt_sub: float = 1.0 / 60.0
