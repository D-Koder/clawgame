extends Node
class_name GameManager

signal score_changed(new_score: int)
signal state_changed(new_state: String)
signal balls_caught(count: int)

enum State { IDLE, DROPPING, DIGGING, RISING }

@export var config: GameConfig

var claw: Claw
var pit_spawner: PitSpawner
var state: int = State.IDLE
var score: int = 0
var held_balls: Array = []
var balls: Array = []

var transition_timer: float = 0.0
var resistance_force: float = 0.0

var dt = 1.0 / 60.0

func _ready() -> void:
	if not config:
		config = GameConfig.new()
	set_process(false)

func initialize(p_claw: Claw, p_pit_spawner: PitSpawner) -> void:
	claw = p_claw
	pit_spawner = p_pit_spawner
	balls = p_pit_spawner.get_balls()

	if claw:
		claw.dropping.connect(_on_claw_drop)

	state = State.IDLE
	set_process(true)

func _process(_delta: float) -> void:
	match state:
		State.IDLE:
			claw.animate_open()
		State.DROPPING:
			_process_dropping()
		State.DIGGING:
			_process_digging()
		State.RISING:
			_process_rising()

func _process_dropping() -> void:
	var free_balls = _get_free_balls()
	_apply_physics(free_balls)
	_push_balls_from_claw(free_balls)

	resistance_force = _calculate_resistance(free_balls)
	var base_speed = config.drop_speed * 0.25 if resistance_force > 0.0 else config.drop_speed
	var speed_factor = max(0.3, 1.0 - resistance_force / 150.0)
	claw.move_down(base_speed * dt * speed_factor)

	if resistance_force > 25.0 or claw.claw_y >= config.max_drop_y:
		_grab_balls()
		state = State.DIGGING
		transition_timer = 0.0
		claw.animate_close()

func _process_digging() -> void:
	transition_timer += dt
	if transition_timer >= config.dig_time:
		state = State.RISING
		transition_timer = 0.0

func _process_rising() -> void:
	claw.move_down(-config.rise_speed * dt)
	for ball in held_balls:
		ball.freeze = true
		ball.global_position = claw.get_grab_pos() - Vector2(0, 50)

	if claw.claw_y <= config.rest_y:
		claw.move_to_rest()
		_deposit_balls()
		state = State.IDLE
		state_changed.emit("idle")

func _apply_physics(ball_list: Array) -> void:
	for ball in ball_list:
		var rb = ball as RigidBody2D
		if rb:
			var v = (rb.global_position - rb.get_meta("prev_pos", rb.global_position)) * config.damping
			rb.set_meta("prev_pos", rb.global_position)
			rb.global_position += v + Vector2(0, config.gravity * dt * dt)

func _push_balls_from_claw(ball_list: Array) -> void:
	var claw_pos = claw.get_claw_pos() + claw.position
	for ball in ball_list:
		var rb = ball as RigidBody2D
		if rb:
			var delta = rb.global_position - claw_pos
			var dist = max(delta.length(), 0.01)
			if dist < config.push_radius + config.ball_radius:
				var overlap = (config.push_radius + config.ball_radius - dist) * config.push_factor
				rb.global_position += delta / dist * overlap

func _calculate_resistance(ball_list: Array) -> float:
	var resistance = 0.0
	var claw_pos = claw.get_claw_pos() + claw.position
	for ball in ball_list:
		var rb = ball as RigidBody2D
		if rb:
			var dist = rb.global_position.distance_to(claw_pos)
			if dist < config.push_radius + config.ball_radius:
				resistance += (config.push_radius + config.ball_radius - dist)
	return resistance

func _grab_balls() -> void:
	var caught = claw.attempt_grab(balls)
	held_balls.clear()
	for ball in caught:
		var rb = ball as RigidBody2D
		if rb:
			rb.freeze = true
			held_balls.append(ball)
	if held_balls.size() > 0:
		balls_caught.emit(held_balls.size())

func _deposit_balls() -> void:
	for ball in held_balls:
		var rb = ball as RigidBody2D
		if rb:
			rb.freeze = false
		if ball.ball_type:
			score += ball.ball_type.value
	score_changed.emit(score)
	held_balls.clear()

func _get_free_balls() -> Array:
	var free = []
	for ball in balls:
		if ball not in held_balls:
			free.append(ball)
	return free

func _on_claw_drop() -> void:
	if state == State.IDLE:
		state = State.DROPPING
		state_changed.emit("dropping")

func reset_game() -> void:
	score = 0
	held_balls.clear()
	pit_spawner.spawn_pit()
	balls = pit_spawner.get_balls()
	state = State.IDLE
	claw.move_to_rest()
	claw.animate_open()
	score_changed.emit(score)
	state_changed.emit("idle")
