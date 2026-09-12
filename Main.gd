extends Node2D

@onready var claw = $Claw
@onready var pit_spawner = $PitSpawner
@onready var hud = $HUD
@onready var reset_button = $HUD/VBoxContainer/ResetButton

var config: GameConfig

func _ready() -> void:
	config = GameConfig.new()

	claw.config = config
	pit_spawner.config = config

	pit_spawner.spawn_pit()

	GameManager.config = config
	GameManager.initialize(claw, pit_spawner)

	reset_button.pressed.connect(_on_reset_pressed)

func _on_reset_pressed() -> void:
	GameManager.reset_game()
