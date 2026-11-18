extends Node3D

const Victoria = preload("res://scripts/vehicles/benz_victoria.gd")

@onready var car: Victoria = $PetersburgDistrict/VehicleTrial/BenzVictoria
@onready var camera: Camera3D = $Camera
@onready var speed_label: Label = $Controls/Speed

var _start: Transform3D


func _ready() -> void:
	var district_driving: Node = $PetersburgDistrict/DistrictDriving
	district_driving.process_mode = Node.PROCESS_MODE_DISABLED
	$PetersburgDistrict/DistrictHUD.hide()
	var player: CharacterBody3D = $PetersburgDistrict/PlayerSpawn/Player
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.hide()
	player.collision_layer = 0
	player.collision_mask = 0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_start = car.global_transform
	camera.make_current()
	_update_camera(1.0)


func _physics_process(_delta: float) -> void:
	car.set_drive_input(Input.get_axis(&"move_backward", &"move_forward"),
			Input.get_axis(&"move_right", &"move_left"), Input.is_action_pressed(&"jump"))
	# Keep the district's activity observer near the test car.
	$PetersburgDistrict/PlayerSpawn/Player.global_position = car.global_position


func _process(delta: float) -> void:
	_update_camera(1.0 - exp(-delta * 8.0))
	speed_label.text = "%d км/ч" % roundi(absf(car.drive_speed) * 3.6)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_R:
		car.reset_drive(_start)
		_update_camera(1.0)
	elif event.physical_keycode in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]:
		car.set_paint(event.physical_keycode - KEY_1)


func _update_camera(weight: float) -> void:
	var focus := car.global_position + Vector3.UP * 1.04
	var target := focus + car.global_basis * Vector3(0.95, 2.45, 5.7)
	var ray := PhysicsRayQueryParameters3D.create(focus, target, 1, [car.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		target = hit.position + hit.normal * 0.18
	camera.global_position = camera.global_position.lerp(target, weight)
	if camera.global_position.distance_squared_to(focus) > 0.035:
		camera.look_at(focus)
