extends Node2D

# Direct port of the HTML/Canvas claw prototype. State machine, verlet
# physics and grab logic are kept 1:1 with the JS version so the feel
# matches; only rendering (Canvas -> _draw) and input (pointer -> mouse
# events) changed.

# ---------- Layout ----------
const CANVAS_W := 340.0
const CANVAS_H := 400.0
const WALL_L := 20.0
const WALL_R := CANVAS_W - 20.0
const FLOOR_Y := CANVAS_H - 10.0
const CANVAS_ORIGIN := Vector2(10, 70)

# ---------- Tuning (mirrors `cfg` in the JS) ----------
const REST_Y := 35.0
const MAX_DROP_Y := 320.0
const DROP_SPEED := 200.0
const RISE_SPEED := 240.0
const DIG_TIME := 0.6
const PUSH_RADIUS := 32.0
const CATCH_RADIUS := 55.0
const MAX_GRAB := 12
const MIN_X := 40.0
const MAX_X := CANVAS_W - 40.0
const GRAVITY := 700.0
const DAMPING := 0.94
const DT_SUB := 1.0 / 60.0
const POSE_SCALE := 0.40

class BallType:
	var color: Color
	var value: int
	var weight: float
	func _init(c: Color, v: int, w: float) -> void:
		color = c
		value = v
		weight = w

var TYPES := [
	BallType.new(Color("F1EFE8"), 1, 0.65),
	BallType.new(Color("D85A30"), 3, 0.06),
	BallType.new(Color("378ADD"), 3, 0.06),
	BallType.new(Color("7F77DD"), 5, 0.04),
	BallType.new(Color("EF9F27"), 4, 0.04),
]

class Ball:
	var pos: Vector2
	var prev: Vector2
	var r: float
	var type: BallType
	func _init(p: Vector2, radius: float, t: BallType) -> void:
		pos = p
		prev = p
		r = radius
		type = t

class HeldBall:
	var ball: Ball
	var offset: Vector2
	func _init(b: Ball, off: Vector2) -> void:
		ball = b
		offset = off

enum State { IDLE, DROPPING, DIGGING, RISING }

var OPEN_POSE := {
	"L": [Vector2(82, 22), Vector2(29, 75), Vector2(29, 179)],
	"R": [Vector2(258, 22), Vector2(311, 75), Vector2(311, 179)],
}
var CLOSED_POSE := {
	"L": [Vector2(93, 75), Vector2(93, 157), Vector2(170, 209)],
	"R": [Vector2(247, 75), Vector2(247, 157), Vector2(170, 209)],
}

var state: int = State.IDLE
var claw_x: float = CANVAS_W / 2.0
var claw_y: float = REST_Y
var transition_timer: float = 0.0
var claw_openness: float = 1.0
var held: Array = []          # Array[HeldBall]
var balls: Array = []         # Array[Ball]
var score: int = 0
var tray_colors: Array = []   # Array[Color]
var dragging: bool = false

@onready var reset_button: Button = $UI/ResetButton

func _ready() -> void:
	spawn_pit()
	reset_button.pressed.connect(_on_reset_pressed)

# ---------- Setup ----------

func pick_type() -> BallType:
	var roll := randf()
	var acc := 0.0
	for t in TYPES:
		acc += t.weight
		if roll <= acc:
			return t
	return TYPES[0]

func spawn_pit() -> void:
	balls.clear()
	var r := 12.0
	var row := 0
	var y := FLOOR_Y - r
	while y > 200.0:
		var offset := 0.0 if row % 2 == 0 else r
		var x := WALL_L + r + offset
		while x < WALL_R - r:
			var b := Ball.new(
				Vector2(x + randf_range(-1.0, 1.0), y + randf_range(-1.0, 1.0)),
				r, pick_type()
			)
			b.prev = Vector2(x + randf_range(-1.0, 1.0), y + randf_range(-1.0, 1.0))
			balls.append(b)
			x += r * 2.0
		y -= r * 1.6
		row += 1

# ---------- Physics ----------

func verlet_step(list: Array) -> void:
	for b in list:
		var v: Vector2 = (b.pos - b.prev) * DAMPING
		b.prev = b.pos
		b.pos += v + Vector2(0, GRAVITY * DT_SUB * DT_SUB)

	for _iter in range(3):
		for b in list:
			b.pos.x = clamp(b.pos.x, WALL_L + b.r, WALL_R - b.r)
			b.pos.y = min(b.pos.y, FLOOR_Y - b.r)

		for i in range(list.size()):
			for j in range(i + 1, list.size()):
				var a: Ball = list[i]
				var b2: Ball = list[j]
				var delta: Vector2 = b2.pos - a.pos
				var dist: float = max(delta.length(), 0.01)
				var min_dist: float = a.r + b2.r
				if dist < min_dist:
					var overlap := (min_dist - dist) / 2.0
					var n := delta / dist
					a.pos -= n * overlap
					b2.pos += n * overlap

		if state == State.DROPPING or state == State.DIGGING:
			var claw_pos := Vector2(claw_x, claw_y)
			for b in list:
				_push_from_point(b, claw_pos, PUSH_RADIUS, 0.05)

func _push_from_point(b: Ball, point: Vector2, radius: float, factor: float) -> void:
	var d: Vector2 = b.pos - point
	var dist: float = max(d.length(), 0.01)
	if dist < radius + b.r:
		var overlap := (radius + b.r - dist) * factor
		b.pos += d / dist * overlap

func attempt_grab() -> Array:
	var grab_pos := Vector2(claw_x, claw_y + 50.0)
	var matches: Array = []
	for b in balls:
		if b.pos.distance_to(grab_pos) < CATCH_RADIUS + b.r:
			matches.append(b)
	matches.sort_custom(func(a, b): return a.pos.distance_to(grab_pos) < b.pos.distance_to(grab_pos))
	if matches.size() > MAX_GRAB:
		matches = matches.slice(0, MAX_GRAB)
	return matches

func current_pose() -> Dictionary:
	var pose := {"L": [], "R": []}
	for side in ["L", "R"]:
		for i in OPEN_POSE[side].size():
			var o: Vector2 = OPEN_POSE[side][i] * POSE_SCALE
			var c: Vector2 = CLOSED_POSE[side][i] * POSE_SCALE
			pose[side].append(o.lerp(c, 1.0 - claw_openness))
	return pose

# ---------- Main loop ----------

func _process(_delta: float) -> void:
	var free_balls: Array = balls
	if held.size() > 0:
		var held_ids := {}
		for h in held:
			held_ids[h.ball] = true
		free_balls = []
		for b in balls:
			if not held_ids.has(b):
				free_balls.append(b)
	verlet_step(free_balls)

	match state:
		State.IDLE:
			claw_openness = min(1.0, claw_openness + 0.1)
		State.DROPPING:
			_process_dropping(free_balls)
		State.DIGGING:
			transition_timer += DT_SUB
			claw_openness = max(0.0, 1.0 - transition_timer / DIG_TIME)
			if transition_timer >= DIG_TIME:
				state = State.RISING
				transition_timer = 0.0
		State.RISING:
			_process_rising()

	queue_redraw()

func _process_dropping(free_balls: Array) -> void:
	claw_openness = 1.0
	var pose := current_pose()
	var claw_pos := Vector2(claw_x, claw_y)
	var tip_offset := Vector2(170, 30) * POSE_SCALE
	var tip_l: Vector2 = claw_pos + pose.L[pose.L.size() - 1] - tip_offset
	var tip_r: Vector2 = claw_pos + pose.R[pose.R.size() - 1] - tip_offset

	for b in free_balls:
		_push_from_point(b, claw_pos, PUSH_RADIUS, 0.08)
		_push_from_point(b, tip_l, 16.0, 0.06)
		_push_from_point(b, tip_r, 16.0, 0.06)

	var resistance := 0.0
	for b in free_balls:
		var dist: float = b.pos.distance_to(claw_pos)
		if dist < PUSH_RADIUS + b.r:
			resistance += (PUSH_RADIUS + b.r - dist)

	var base_speed: float = DROP_SPEED * 0.25 if resistance > 0.0 else DROP_SPEED
	var speed_factor: float = max(0.3, 1.0 - resistance / 150.0)
	claw_y += base_speed * DT_SUB * speed_factor

	if resistance > 25.0 or claw_y >= MAX_DROP_Y:
		var caught := attempt_grab()
		held.clear()
		for b in caught:
			b.prev = b.pos
			held.append(HeldBall.new(b, b.pos - claw_pos))
		transition_timer = 0.0
		state = State.DIGGING
	elif held.size() >= 5:
		state = State.DIGGING
		transition_timer = 0.0

func _process_rising() -> void:
	claw_openness = 0.0
	claw_y -= RISE_SPEED * DT_SUB
	var claw_pos := Vector2(claw_x, claw_y)
	for h in held:
		h.ball.pos = claw_pos + h.offset
		h.ball.prev = h.ball.pos

	if claw_y <= REST_Y:
		claw_y = REST_Y
		if held.size() > 0:
			var held_ids := {}
			for h in held:
				score += h.ball.type.value
				tray_colors.append(h.ball.type.color)
				held_ids[h.ball] = true
			var remaining: Array = []
			for b in balls:
				if not held_ids.has(b):
					remaining.append(b)
			balls = remaining
			held.clear()
		state = State.IDLE

# ---------- Input ----------

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if state == State.IDLE:
				dragging = true
				claw_x = clamp(event.position.x - CANVAS_ORIGIN.x, MIN_X, MAX_X)
		else:
			if dragging and state == State.IDLE:
				state = State.DROPPING
			dragging = false
	elif event is InputEventMouseMotion and dragging:
		claw_x = clamp(event.position.x - CANVAS_ORIGIN.x, MIN_X, MAX_X)

func _on_reset_pressed() -> void:
	spawn_pit()
	score = 0
	tray_colors.clear()

# ---------- Drawing ----------

func _draw() -> void:
	draw_rect(Rect2(CANVAS_ORIGIN, Vector2(CANVAS_W, CANVAS_H)), Color("2a2a2a"))

	var font := ThemeDB.fallback_font
	draw_string(font, CANVAS_ORIGIN + Vector2(0, -42), _state_label(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("aaaaaa"))
	draw_string(font, CANVAS_ORIGIN + Vector2(CANVAS_W - 90, -42), "Total: %d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("aaaaaa"))

	var tx := CANVAS_ORIGIN.x
	var ty := CANVAS_ORIGIN.y - 18
	for c in tray_colors:
		if tx > CANVAS_ORIGIN.x + CANVAS_W - 12:
			break
		draw_circle(Vector2(tx, ty), 6, c)
		tx += 14

	draw_line(CANVAS_ORIGIN + Vector2(claw_x, REST_Y), CANVAS_ORIGIN + Vector2(claw_x, claw_y), Color("444444"), 1.5)
	draw_line(CANVAS_ORIGIN + Vector2(20, REST_Y), CANVAS_ORIGIN + Vector2(CANVAS_W - 20, REST_Y), Color("444444"), 0.5)

	_draw_claw()

	var grab_pos := CANVAS_ORIGIN + Vector2(claw_x, claw_y + 50)
	draw_arc(grab_pos, 24, 0, TAU, 32, Color(1, 1, 0, 0.5), 1.0)
	draw_arc(grab_pos, CATCH_RADIUS - 20, 0, TAU, 32, Color(0, 0.4, 1, 0.6), 2.0)

	for b in balls:
		draw_circle(CANVAS_ORIGIN + b.pos, b.r, b.type.color)
		draw_arc(CANVAS_ORIGIN + b.pos, b.r, 0, TAU, 16, Color(0, 0, 0, 0.15), 0.5)

func _state_label() -> String:
	match state:
		State.IDLE:
			return "drag to aim, let go to drop"
		State.DROPPING:
			return "lowering"
		State.DIGGING:
			return "closing jaws" if held.size() > 0 else "empty grab!"
		State.RISING:
			return ("rising with %d" % held.size()) if held.size() > 0 else "rising empty"
	return ""

func _draw_claw() -> void:
	var pose := current_pose()
	var mount := Vector2(claw_x, claw_y)
	var tip_offset := Vector2(170, 30) * POSE_SCALE

	for side in ["L", "R"]:
		var prev := mount
		for p in pose[side]:
			var world: Vector2 = mount + p - tip_offset
			draw_line(CANVAS_ORIGIN + prev, CANVAS_ORIGIN + world, Color("c9a06e"), 10.0)
			prev = world

	draw_circle(CANVAS_ORIGIN + mount, 5, Color("e8c48f"))
	for side in ["L", "R"]:
		for p in pose[side]:
			draw_circle(CANVAS_ORIGIN + mount + p - tip_offset, 5, Color("e8c48f"))
