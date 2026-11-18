extends Node

const SCREEN := preload("res://scenes/ui/death_screen.tscn")

@onready var player := $"../PlayerSpawn/Player"
@onready var spawn: Marker3D = $"../PlayerSpawn"
var screen: CanvasLayer

func _ready() -> void:
	screen = SCREEN.instantiate()
	add_child(screen)
	player.died.connect(_show_death)

func _physics_process(_delta: float) -> void:
	if player.global_position.y < -15:
		player.die(&"fall")

func _show_death(reason: StringName) -> void:
	var shade: ColorRect = screen.get_node("Shade")
	var words: Control = screen.get_node("Words")
	var title: Label = words.get_node("Lines/Title")
	var subtitle: Label = words.get_node("Lines/Subtitle")
	title.text = "УТОНУЛЪ" if reason == &"water" else "ПОГИБЪ"
	subtitle.text = "В следующий раз научитесь плавать" if reason == &"water" else ""
	shade.color.a = 0.0
	words.modulate.a = 0.0
	screen.show()
	var sequence := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	sequence.tween_property(shade, "color:a", 0.85, 0.4)
	sequence.parallel().tween_property(words, "modulate:a", 1.0, 0.45)
	sequence.tween_interval(2.15)
	sequence.tween_property(shade, "color:a", 1.0, 0.3)
	sequence.parallel().tween_property(words, "modulate:a", 0.0, 0.3)
	sequence.tween_callback(_respawn)
	sequence.tween_property(shade, "color:a", 0.0, 0.45)
	sequence.tween_callback(screen.hide)

func _respawn() -> void:
	player.respawn_at(spawn.global_position + Vector3.UP * 0.05)
