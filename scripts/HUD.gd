extends CanvasLayer
class_name HUD

@onready var state_label: Label = $VBoxContainer/StateLabel
@onready var score_label: Label = $VBoxContainer/ScoreLabel
@onready var tray_container: HBoxContainer = $VBoxContainer/TrayContainer

var tray_colors: Array = []

func _ready() -> void:
	if GameManager:
		GameManager.score_changed.connect(_on_score_changed)
		GameManager.state_changed.connect(_on_state_changed)
		GameManager.balls_caught.connect(_on_balls_caught)

	_update_ui()

func _on_score_changed(new_score: int) -> void:
	if state_label:
		score_label.text = "Total: %d" % new_score

func _on_state_changed(new_state: String) -> void:
	if state_label:
		state_label.text = new_state

func _on_balls_caught(count: int) -> void:
	if state_label and count > 0:
		state_label.text = "closing jaws"

func add_tray_color(color: Color) -> void:
	var dot = Control.new()
	dot.custom_minimum_size = Vector2(12, 12)
	dot.modulate = color
	if tray_container:
		tray_container.add_child(dot)
	tray_colors.append(color)

func clear_tray() -> void:
	tray_colors.clear()
	if tray_container:
		for child in tray_container.get_children():
			child.queue_free()

func _update_ui() -> void:
	if state_label:
		state_label.text = "drag to aim, let go to drop"
	if score_label:
		score_label.text = "Total: 0"
