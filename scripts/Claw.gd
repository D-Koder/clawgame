extends Node2D
class_name Claw

signal dropping
signal digging
signal rising
signal grab_complete(balls: Array)

@export var config: GameConfig

var claw_x: float
var claw_y: float
var claw_openness: float = 1.0
var dragging: bool = false

var open_pose = {
	"L": [Vector2(82, 22), Vector2(29, 75), Vector2(29, 179)],
	"R": [Vector2(258, 22), Vector2(311, 75), Vector2(311, 179)],
}
var closed_pose = {
	"L": [Vector2(93, 75), Vector2(93, 157), Vector2(170, 209)],
	"R": [Vector2(247, 75), Vector2(247, 157), Vector2(170, 209)],
}
var pose_scale: float = 0.40

var grab_zone: Area2D

func _ready() -> void:
	if not config:
		config = GameConfig.new()
	claw_x = config.canvas_width / 2.0
	claw_y = config.rest_y
	position = Vector2(10, 70)

	_setup_grab_zone()

func _setup_grab_zone() -> void:
	grab_zone = Area2D.new()
	grab_zone.name = "GrabZone"
	var shape = CircleShape2D.new()
	shape.radius = config.catch_radius
	var collision = CollisionShape2D.new()
	collision.shape = shape
	grab_zone.add_child(collision)
	add_child(grab_zone)

func _process(_delta: float) -> void:
	position.x = claw_x

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			_on_mouse_down(event.position)
		else:
			if dragging:
				_on_mouse_up()
			dragging = false
	elif event is InputEventMouseMotion and dragging:
		_on_mouse_move(event.position)

func _on_mouse_down(screen_pos: Vector2) -> void:
	claw_x = clamp(screen_pos.x - position.x, config.min_x, config.max_x)

func _on_mouse_move(screen_pos: Vector2) -> void:
	claw_x = clamp(screen_pos.x - position.x, config.min_x, config.max_x)

func _on_mouse_up() -> void:
	dropping.emit()

func get_grab_pos() -> Vector2:
	return global_position + Vector2(claw_x, claw_y + 50.0)

func attempt_grab(balls: Array) -> Array:
	var grab_pos = get_grab_pos()
	var matches = []
	for b in balls:
		if (b as Ball).global_position.distance_to(grab_pos) < config.catch_radius + config.ball_radius:
			matches.append(b)
	matches.sort_custom(func(a, b): return (a as Ball).global_position.distance_to(grab_pos) < (b as Ball).global_position.distance_to(grab_pos))
	if matches.size() > config.max_grab:
		matches = matches.slice(0, config.max_grab)
	return matches

func animate_open() -> void:
	var tween = create_tween()
	tween.tween_property(self, "claw_openness", 1.0, 0.2)

func animate_close() -> void:
	var tween = create_tween()
	tween.tween_property(self, "claw_openness", 0.0, config.dig_time)

func current_pose() -> Dictionary:
	var pose = {"L": [], "R": []}
	for side in ["L", "R"]:
		for i in open_pose[side].size():
			var o = open_pose[side][i] * pose_scale
			var c = closed_pose[side][i] * pose_scale
			pose[side].append(o.lerp(c, 1.0 - claw_openness))
	return pose

func _draw() -> void:
	var pose = current_pose()
	var mount = Vector2(claw_x, claw_y)
	var tip_offset = Vector2(170, 30) * pose_scale

	draw_line(Vector2(claw_x, config.rest_y), Vector2(claw_x, claw_y), Color("444444"), 1.5)

	for side in ["L", "R"]:
		var prev = mount
		for p in pose[side]:
			var world = mount + p - tip_offset
			draw_line(prev, world, Color("c9a06e"), 10.0)
			prev = world

	draw_circle(mount, 5, Color("e8c48f"))
	for side in ["L", "R"]:
		for p in pose[side]:
			draw_circle(mount + p - tip_offset, 5, Color("e8c48f"))

	queue_redraw()

func set_claw_position(x: float) -> void:
	claw_x = x
	queue_redraw()

func move_down(amount: float) -> void:
	claw_y += amount
	queue_redraw()

func move_to_rest() -> void:
	claw_y = config.rest_y
	queue_redraw()

func get_claw_pos() -> Vector2:
	return Vector2(claw_x, claw_y)
