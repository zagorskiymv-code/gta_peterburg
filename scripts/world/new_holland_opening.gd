extends Node3D

signal finished

const Period = preload("res://scripts/ui/period_theme.gd")
const Player = preload("res://scripts/player/player_controller.gd")
const DURATION := 15.4
const SEAT_OFFSET := Vector3(1.28, 0, -0.55)

var _player: Player
var _hud: CanvasLayer
var _pause: CanvasLayer
var _camera: Camera3D
var _game_camera: Camera3D
var _ui: CanvasLayer
var _subtitle: Label
var _title: Label
var _time := 0.0
var _playing := false
var _site := Vector3.ZERO
var _final_camera := Transform3D.IDENTITY


func start(world: Node3D, spawn: Marker3D, player: Player, hud: CanvasLayer, pause_menu: CanvasLayer) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = player
	_hud = hud
	_pause = pause_menu
	# Resolve the existing cargo and wait for the generated ground colliders to register.
	var cargo := world.get_node("Landmarks/NewHolland/QuayCargo") as Node3D
	await get_tree().physics_frame
	var space := world.get_world_3d().direct_space_state
	var at := cargo.global_position + SEAT_OFFSET
	var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			at + Vector3.UP * 0.36, at - Vector3.UP * 0.25, 1))
	if ground.is_empty() or ground.normal.y < 0.90:
		push_warning("Пролог: не найден пол у ящиков")
		queue_free()
		return
	_site = ground.position + Vector3.UP * 0.035
	var capsule := player.get_node("CollisionShape3D") as CollisionShape3D
	var fit := PhysicsShapeQueryParameters3D.new()
	fit.shape = capsule.shape
	fit.transform.origin = _site + capsule.position
	fit.collision_mask = 1 | 4 | 8
	fit.exclude = [player.get_rid()]
	if not space.intersect_shape(fit, 1).is_empty():
		push_warning("Пролог: место у ящиков занято")
		queue_free()
		return

	spawn.global_position = _site
	player.global_position = _site
	player.velocity = Vector3.ZERO
	player.camera_yaw = 0.0
	player.camera_pitch = deg_to_rad(-17)
	player._update_camera_pivot()
	player.reset_physics_interpolation()
	_game_camera = player.spring_arm.get_node("Camera3D")
	var arm := player.spring_arm.global_transform
	# Match the spring arm's normal follow pose at the end of the shot.
	var pull := arm.basis.z * player.spring_arm.spring_length
	var sphere := SphereShape3D.new()
	sphere.radius = 0.25
	var clearance := PhysicsShapeQueryParameters3D.new()
	clearance.shape = sphere
	clearance.transform.origin = arm.origin
	clearance.motion = pull
	clearance.collision_mask = player.spring_arm.collision_mask
	clearance.exclude = [player.get_rid()]
	var cast := space.cast_motion(clearance)
	_final_camera = Transform3D(arm.basis, arm.origin + pull * cast[0])
	_camera = Camera3D.new()
	_camera.fov = _game_camera.fov
	_camera.near = _game_camera.near
	add_child(_camera)
	_build_titles()
	_pause.process_mode = Node.PROCESS_MODE_DISABLED
	_hud.hide()
	get_tree().paused = true
	_playing = true
	_camera.make_current()
	_render(0.0)


func _process(delta: float) -> void:
	if not _playing:
		return
	_time += delta
	if _time >= DURATION:
		_finish()
	else:
		_render(_time)


func _input(event: InputEvent) -> void:
	if not _playing:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		Input.action_release(&"jump")
		_finish()
	elif event is InputEventKey or event is InputEventMouseMotion:
		get_viewport().set_input_as_handled()


func _render(time: float) -> void:
	var rise := smoothstep(4.4, 6.2, time)
	var look := (sin((time - 6.1) * 2.5) * 0.54 + 0.10) * smoothstep(5.8, 6.6, time) * (1.0 - smoothstep(8.7, 10.4, time))
	var visual = _player.character_visual
	visual.rotation.y = lerpf(-1.01, 0.0, smoothstep(6.8, 12.1, time))
	visual.pose_opening(rise, look)

	var start_at := _site + Vector3(11.4, 5.6, -9.0)
	var near_at := _site + Vector3(3.9, 2.20, -1.30)
	var a := smoothstep(0.0, 6.4, time)
	var position := start_at.lerp(near_at, a)
	var center := (_site + Vector3(5.8, 3.1, 2.5)).lerp(_site + Vector3.UP * lerpf(0.95, 1.3, rise), a)
	if time < 10.4:
		_camera.global_transform = Transform3D(Basis.looking_at(position.direction_to(center)), position)
	else:
		# Stay in the courtyard and arc behind the hero before settling into the gameplay pose.
		var blend := smoothstep(10.4, DURATION, time)
		var behind := _final_camera.origin
		var arc := near_at.bezier_interpolate(_site + Vector3(5.8, 2.6, 0.6),
				behind + Vector3(3.0, 0.6, 0.4), behind, blend)
		var focus := center.lerp(_player.spring_arm.global_position, blend)
		_camera.global_transform = Transform3D(Basis.looking_at(arc.direction_to(focus)), arc)
	_subtitle.modulate.a = _fade(time, 7.0, 9.9)
	_title.modulate.a = _fade(time, 9.75, 13.5)


func _fade(time: float, begin: float, end: float) -> float:
	return smoothstep(begin, begin + 0.40, time) * (1.0 - smoothstep(end - 0.55, end, time))


func _build_titles() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 28
	add_child(_ui)
	_subtitle = _caption("Эхъ, чёртъ побери… Опять всё сначала", 23, 0.84, 0.0)
	_title = _caption("Санктъ-Петербургъ. 1899 годъ", 37, 0.35, 0.0)
	_caption("Пробел — пропустить", 15, 0.94, 1.0)


func _caption(text: String, pixels: int, fraction: float, alpha: float) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", Period.typeface())
	label.add_theme_font_size_override("font_size", pixels)
	label.add_theme_color_override("font_color", Period.CREAM)
	label.add_theme_color_override("font_outline_color", Period.INK)
	label.add_theme_constant_override("outline_size", 8)
	label.modulate.a = alpha
	_ui.add_child(label)
	label.anchor_right = 1.0
	label.anchor_top = fraction
	label.anchor_bottom = fraction
	return label


func _finish() -> void:
	_playing = false
	_player.character_visual.leave_seat()
	_player.character_visual.rotation = Vector3.ZERO
	_game_camera.position.z = _player.spring_arm.global_position.distance_to(_final_camera.origin)
	_game_camera.make_current()
	_pause.process_mode = Node.PROCESS_MODE_ALWAYS
	_hud.show()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	finished.emit()
	queue_free()
