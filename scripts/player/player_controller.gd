extends CharacterBody3D

signal died(reason: StringName)

var is_dead := false

const WALK_SPEED := 5.0
const SPRINT_SPEED := 38.0
const JUMP_SPEED := 4.2
const MOUSE_SENSITIVITY := 0.0025
const MIN_CAMERA_PITCH := -70.0
const MAX_CAMERA_PITCH := 30.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D

@onready var character_visual := $CharacterVisual

var camera_yaw := 0.0
var camera_pitch := 0.0


func _ready() -> void:
	camera_yaw = rotation.y + camera_pivot.rotation.y
	camera_pitch = camera_pivot.rotation.x
	spring_arm.add_excluded_object(get_rid())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	if event.is_action_pressed(&"ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_yaw = wrapf(camera_yaw - event.screen_relative.x * MOUSE_SENSITIVITY, -PI, PI)
		camera_pitch = clampf(
			camera_pitch - event.screen_relative.y * MOUSE_SENSITIVITY,
			deg_to_rad(MIN_CAMERA_PITCH),
			deg_to_rad(MAX_CAMERA_PITCH)
		)
		_update_camera_pivot()


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	var move_input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_backward")
	var direction := Vector3(move_input.x, 0.0, move_input.y).rotated(Vector3.UP, camera_yaw)
	var sprinting := Input.is_action_pressed(&"sprint")
	var speed := SPRINT_SPEED if sprinting else WALK_SPEED
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	if not is_on_floor():
		velocity += get_gravity() * delta
	elif Input.is_action_just_pressed(&"jump"):
		velocity.y = JUMP_SPEED

	move_and_slide()
	character_visual.animate(delta, get_position_delta(), direction,
			is_on_floor(), get_floor_normal() if is_on_floor() else Vector3.UP, velocity.y, sprinting)


func _update_camera_pivot() -> void:
	camera_pivot.rotation = Vector3(camera_pitch, camera_yaw - rotation.y, 0.0)



func die(reason: StringName) -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector3.ZERO
	died.emit(reason)


func respawn_at(destination: Vector3) -> void:
	global_position = destination
	velocity = Vector3.ZERO
	reset_physics_interpolation()
	is_dead = false
