extends Node3D

const Citizen = preload("res://scripts/npc/citizen_npc.gd")
const OVERVIEW := Vector3(0, 1.0, 0)
const OUTFIT_NAMES := ["Сюртук", "Пальто", "Платье", "Накидка", "Часовой", "Патрульный",
		"Рабочий", "Купец", "Служащий", "Горожанка", "Пожилой", "Торговец"]
const GROUP_CENTERS := [6.8, 1.5, -5.4]

@onready var camera: Camera3D = $Camera
@onready var lineup: Node3D = $Lineup

var walking := false
var view := 0
var side_view := false


func _ready() -> void:
	for npc: Citizen in lineup.get_children():
		npc.set_physics_process(false)
		var label := Label3D.new()
		label.name = "OutfitName"
		label.text = OUTFIT_NAMES[npc.outfit - 1]
		label.position.y = 2.18
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 38
		label.pixel_size = 0.0046
		label.outline_size = 7
		npc.add_child(label)
	get_viewport().size_changed.connect(_update_camera)
	_update_camera()


func _physics_process(delta: float) -> void:
	for npc: Citizen in lineup.get_children():
		var step := Vector3.FORWARD * npc.walk_speed * delta if walking else Vector3.ZERO
		npc.visual.animate(delta, step, Vector3.ZERO, true, Vector3.UP, 0.0, false, npc.stride_scale)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_SPACE:
			walking = not walking
		KEY_1, KEY_2, KEY_3, KEY_4:
			view = event.physical_keycode - KEY_1
			_update_camera()
		KEY_V:
			side_view = not side_view
			_update_camera()


func _update_camera() -> void:
	var focus := OVERVIEW
	var distance := 16.0
	if view > 0:
		focus.x = GROUP_CENTERS[view - 1]
		distance = 6.9 if view < 3 else 9.0
	var width_ratio := get_viewport().get_visible_rect().size.aspect()
	distance *= maxf(1.0, 1.70 / width_ratio)
	for npc: Citizen in lineup.get_children():
		npc.visible = view == 0 or npc.citizen_type == [0, Citizen.CitizenType.NOBLE, Citizen.CitizenType.SOLDIER, Citizen.CitizenType.RESIDENT][view]
		npc.get_node("OutfitName").visible = view != 0
	var azimuth := deg_to_rad(38.0) if side_view else 0.0
	camera.position = focus + Vector3(sin(azimuth) * distance, 0.81 if view == 0 else 0.37, -cos(azimuth) * distance)
	camera.look_at(focus)
