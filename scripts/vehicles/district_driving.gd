extends Node3D

signal transport_entered(vehicle: Node3D)
## Emitted after the car stops and the player successfully steps out.
signal transport_exited(vehicle: Node3D)

const Victoria = preload("res://scripts/vehicles/benz_victoria.gd")
const Model = preload("res://scripts/vehicles/victoria_model.gd")
const Player = preload("res://scripts/player/player_controller.gd")
const Visual = preload("res://scripts/player/historical_character_visual.gd")

const ENTRY_DISTANCE := 2.35
const DEFAULT_CAMERA_PITCH := -17.0
const EXIT_OFFSETS: Array[Vector3] = [
	Vector3(-1.56, 0, 0.22), Vector3(1.56, 0, 0.22),
	Vector3(-1.59, 0, 1.02), Vector3(1.59, 0, 1.02), Vector3(0, 0, 2.19),
]

var _player: Player
var _car: Victoria
var _visual: Visual
var _camera: Camera3D
var _follow_arm: SpringArm3D
var hud_hint := ""
var _parked_pose: Transform3D
var _visual_transform: Transform3D
var _player_layer := 0
var _player_mask := 0
var _interaction_pending := false
var _driving := false
var _exit_pending := false
var _exit_denied := false
var _driver_death := false


func configure(player: Player, car: Victoria) -> void:
	_player = player
	_car = car
	_visual = player.character_visual
	_parked_pose = car.global_transform
	_car.driver_died.connect(_player.die)
	_player.died.connect(_on_driver_death)

	_follow_arm = SpringArm3D.new()
	_follow_arm.name = "DrivingCameraArm"
	_follow_arm.spring_length = 5.25
	_follow_arm.collision_mask = 1
	_follow_arm.margin = 0.13
	var shape := SphereShape3D.new()
	shape.radius = 0.21
	_follow_arm.shape = shape
	_follow_arm.position = Vector3(0, 1.53, 0.02)
	_follow_arm.rotation.x = deg_to_rad(DEFAULT_CAMERA_PITCH)
	_car.add_child(_follow_arm)
	_follow_arm.add_excluded_object(_car.get_rid())
	_follow_arm.add_excluded_object(_player.get_rid())
	_camera = Camera3D.new()
	_camera.fov = 63.0
	_camera.near = 0.08
	_follow_arm.add_child(_camera)



func _input(event: InputEvent) -> void:
	if not _driving or _player.is_dead or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		_follow_arm.rotation.y = wrapf(
				_follow_arm.rotation.y - event.screen_relative.x * Player.MOUSE_SENSITIVITY, -PI, PI)
		_follow_arm.rotation.x = clampf(
				_follow_arm.rotation.x - event.screen_relative.y * Player.MOUSE_SENSITIVITY,
				deg_to_rad(Player.MIN_CAMERA_PITCH), deg_to_rad(Player.MAX_CAMERA_PITCH))
		# Keep the walking camera's orientation intact while driving.
		get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or event.physical_keycode != KEY_E:
		return
	if _player.is_dead or (not _driving and not _can_enter()):
		return
	_interaction_pending = true
	get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	if _driver_death:
		_driver_death = false
		_dismount(_player.global_position)
		_car.reset_drive(_parked_pose)

	if _interaction_pending:
		_interaction_pending = false
		if _driving:
			_exit_pending = true
		elif _can_enter() and _entry_clear():
			_mount()

	if _driving:
		_player.global_position = _car.global_position
		var braking := _exit_pending or Input.is_action_pressed(&"jump")
		_car.set_drive_input(Input.get_axis(&"move_backward", &"move_forward"),
				Input.get_axis(&"move_right", &"move_left"), braking)
		_visual.pose_seated(_car.steering)
		if _exit_pending and absf(_car.drive_speed) < 0.15 and _car.is_on_floor():
			_exit_pending = false
			var site := _safe_exit()
			_exit_denied = not site.is_finite()
			if not _exit_denied:
				_dismount(site)
				transport_exited.emit(_car)

	_update_prompt()


func _can_enter() -> bool:
	return _player.is_physics_processing() and not _player.is_dead and not _car.has_driver and _player.is_on_floor() \
			and _car.is_on_floor() and absf(_car.drive_speed) < 0.15 \
			and _player.global_position.distance_squared_to(_car.global_position) <= ENTRY_DISTANCE * ENTRY_DISTANCE


func _entry_clear() -> bool:
	var shoulder := Vector3.UP * 0.96
	var route := PhysicsRayQueryParameters3D.create(_player.global_position + shoulder,
			_car.global_position + shoulder, 1 | 4 | 8, [_car.get_rid(), _player.get_rid()])
	return _car.get_world_3d().direct_space_state.intersect_ray(route).is_empty()


func _mount() -> void:
	_driving = true
	_exit_denied = false
	_car.set_driver_occupied(true)
	_player_layer = _player.collision_layer
	_player_mask = _player.collision_mask
	_player.collision_layer = 0
	_player.collision_mask = 0
	_player.velocity = Vector3.ZERO
	_player.set_physics_process(false)
	_visual_transform = _visual.transform
	_visual.reparent(_car, false)
	_visual.transform = Transform3D(Basis.IDENTITY, Model.DRIVER_SEAT)
	_visual.pose_seated()
	_visual.reset_physics_interpolation()
	_follow_arm.rotation = Vector3(deg_to_rad(DEFAULT_CAMERA_PITCH), 0.0, 0.0)
	_camera.make_current()
	transport_entered.emit(_car)


func _dismount(site: Vector3) -> void:
	_driving = false
	_exit_pending = false
	_car.set_drive_input(0.0, 0.0, true)
	_car.set_driver_occupied(false)
	_player.global_position = site
	_player.velocity = Vector3.ZERO
	_player.collision_layer = _player_layer
	_player.collision_mask = _player_mask
	_visual.reparent(_player, false)
	_visual.transform = _visual_transform
	_visual.leave_seat()
	_player.reset_physics_interpolation()
	_player.set_physics_process(true)
	_player.spring_arm.get_node("Camera3D").make_current()


func _safe_exit() -> Vector3:
	var space := _car.get_world_3d().direct_space_state
	var player_shape := _player.get_node("CollisionShape3D") as CollisionShape3D
	var fit := PhysicsShapeQueryParameters3D.new()
	fit.shape = player_shape.shape
	fit.collision_mask = _player_mask | 8
	fit.exclude = [_player.get_rid()]
	for offset in EXIT_OFFSETS:
		var beside := _car.to_global(offset)
		var floor_ray := PhysicsRayQueryParameters3D.create(beside + Vector3.UP * 0.55,
				beside - Vector3.UP * 0.30, 1, [_car.get_rid(), _player.get_rid()])
		var floor_hit := space.intersect_ray(floor_ray)
		if floor_hit.is_empty() or floor_hit.normal.y < 0.83:
			continue
		if absf(floor_hit.position.y - _car.global_position.y) > 0.28:
			continue
		var site: Vector3 = floor_hit.position + Vector3.UP * 0.045
		fit.transform = Transform3D(Basis.IDENTITY, site + player_shape.position)
		if not space.intersect_shape(fit, 1).is_empty():
			continue
		var shoulder := Vector3.UP * 0.92
		var side_ray := PhysicsRayQueryParameters3D.create(_car.global_position + shoulder, site + shoulder,
				1 | 4 | 8, [_car.get_rid(), _player.get_rid()])
		if space.intersect_ray(side_ray).is_empty():
			return site
	return Vector3.INF


func _on_driver_death(_reason: StringName) -> void:
	if _driving:
		_driver_death = true


func current_vehicle() -> Victoria:
	return _car if _driving else null


func _update_prompt() -> void:
	if _driving:
		if _exit_pending:
			hud_hint = "Остановка для выхода"
		elif _exit_denied:
			hud_hint = "Рядом нет безопасного места для выхода"
		else:
			hud_hint = ""
	else:
		hud_hint = "E — сесть за управление" if _can_enter() else ""
