extends Node3D

signal objective_changed(mission_id: String, step: Step)

const Mission = preload("res://scripts/systems/mission_definition.gd")
const Step = preload("res://scripts/systems/mission_step.gd")
const Conversation = preload("res://scripts/world/mission_conversation.gd")
const Wallet = preload("res://scripts/systems/wallet.gd")
const SAVE_PATH := Wallet.SAVE_PATH
enum Status { AVAILABLE, ACTIVE, FAILED, COMPLETE }

var save_path := SAVE_PATH
var status := Status.AVAILABLE
var step_index := 0
var _mission: Mission
var _world: Node3D
var _player: CharacterBody3D
var _hud: CanvasLayer
var _marker: Node3D
var _interaction := false
var _report_failure := false
var _mounted_transport: Callable
var _start_after_opening := false
var _next_missions: Array[Mission]
var _pause_menu: CanvasLayer
var _story := false


func configure(world: Node3D, player: CharacterBody3D, hud: CanvasLayer, mission: Mission,
		mounted_transport := Callable(), start_after_opening := false) -> void:
	_world = world
	_player = player
	_hud = hud
	_mission = mission
	_player.died.connect(_on_player_death)
	_mounted_transport = mounted_transport
	_start_after_opening = start_after_opening
	if not _start_after_opening:
		_load_progress()
	var file := ConfigFile.new()
	file.load(save_path)
	_hud.set_wallet_balance(Wallet.balance(file))
	_update_display()


func configure_story(follow_ups: Array[Mission], pause_menu: CanvasLayer) -> void:
	_story = true
	_next_missions = follow_ups.duplicate()
	_pause_menu = pause_menu


func resume_story() -> String:
	var file := ConfigFile.new()
	if file.load(save_path) != OK:
		start()
		return _mission.id
	var chain: Array[Mission] = [_mission]
	chain.append_array(_next_missions)
	var saved_id := String(file.get_value("campaign", "current_mission", ""))
	var index := 0
	for candidate in chain.size():
		if chain[candidate].id == saved_id or (saved_id.is_empty() and file.has_section(chain[candidate].id)):
			index = candidate
	_mission = chain[index]
	_next_missions.assign(chain.slice(index + 1))
	_start_after_opening = false
	_load_progress()
	if status == Status.COMPLETE and not _next_missions.is_empty():
		_mission = _next_missions.pop_front()
		status = Status.AVAILABLE
	if status == Status.AVAILABLE:
		start()
	else:
		# Vehicles are placed at their mission starts when reopening the district.
		if status == Status.ACTIVE and (not _current().required_transport.is_empty() or _current().kind == Step.Kind.CHASE):
			step_index = 0
		_publish_objective()
	return _mission.id


func _unhandled_key_input(event: InputEvent) -> void:
	if not _mission or not event is InputEventKey or not event.pressed or event.echo or _player.is_dead:
		return
	if event.physical_keycode == KEY_F4 and not _start_after_opening and _player.is_physics_processing() \
			and status in [Status.AVAILABLE, Status.FAILED]:
		start()
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_E and _can_interact():
		_interaction = true
		get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	if _report_failure and not _player.is_dead:
		_report_failure = false
		_hud.post_message("ЗАДАНИЕ ПРОВАЛЕНО", "F4 — повторить задание")
	if status != Status.ACTIVE:
		return
	var step := _current()
	var target := _target(step)
	if target and _marker:
		_marker.global_position = target.global_position
	if step.kind == Step.Kind.REACH and _in_range(step, target):
		if _has_required_transport(step) and (not step.on_foot_only or _player.is_physics_processing()):
			_advance()
	elif step.kind == Step.Kind.PARK_AND_EXIT:
		var car := _world.get_node_or_null(step.required_transport) as CharacterBody3D
		var goal := step.objective
		if _has_required_transport(step) and _is_at_checkpoint(step, target, car):
			goal = "Выйдите из автомобиля — E" if car.is_on_floor() \
					and car.get_real_velocity().slide(Vector3.UP).length() < 0.15 else "Остановитесь внутри маркера"
		_hud.set_mission_status(_mission.title, goal)
	elif (_interaction or step.auto_conversation) and _can_interact():
		if _clear_interaction(target):
			if step.conversation.is_empty():
				_advance()
			else:
				_play_conversation(step, target)
	_interaction = false


func set_chase_prompt(target: Node3D, text: String) -> void:
	if _is_chase_target(target):
		_hud.set_mission_status(_mission.title, text)


func resolve_chase(target: Node3D, escaped: bool) -> void:
	if not _is_chase_target(target):
		return
	if escaped:
		_advance()
	else:
		_fail_active_mission()


func _is_chase_target(target: Node3D) -> bool:
	return status == Status.ACTIVE and _current().kind == Step.Kind.CHASE and _target(_current()) == target


func _play_conversation(step: Step, target: Node3D) -> void:
	var scene := Conversation.new()
	scene.name = "MissionConversation"
	add_child(scene)
	if _marker:
		_marker.hide()
	scene.finished.connect(_advance, CONNECT_ONE_SHOT)
	var subject := _world.get_node_or_null(step.inspection_subject) as Node3D if not step.inspection_subject.is_empty() else null
	scene.start(_player, target, _hud, _pause_menu, step.contact_name, step.conversation, subject)


func start() -> void:
	if not _mission or _mission.steps.is_empty() or _player.is_dead or status not in [Status.AVAILABLE, Status.FAILED]:
		return
	_start_after_opening = false
	if status != Status.FAILED or not _current().keep_on_retry:
		step_index = 0
	status = Status.ACTIVE
	_commit()
	if not _mission.briefing.is_empty():
		_hud.post_message(_mission.title, _mission.briefing, 5.0)


func transport_entered(vehicle: Node3D) -> void:
	if status != Status.ACTIVE:
		return
	var step := _current()
	if step.kind == Step.Kind.ENTER_TRANSPORT and (step.target.is_empty() or vehicle == _target(step)):
		if not step.subtitle.is_empty():
			_hud.post_message("Герой", step.subtitle)
		_advance()


func transport_exited(vehicle: Node3D) -> void:
	if status != Status.ACTIVE or _player.is_dead:
		return
	var step := _current()
	if step.kind == Step.Kind.PARK_AND_EXIT and vehicle == _world.get_node_or_null(step.required_transport) \
			and _is_at_checkpoint(step, _target(step), vehicle):
		_advance()


func _is_at_checkpoint(step: Step, target: Node3D, vehicle: Node3D) -> bool:
	return is_instance_valid(target) and is_instance_valid(vehicle) \
			and vehicle.global_position.distance_squared_to(target.global_position) <= step.radius * step.radius


func _advance() -> void:
	var completed_step := _current()
	step_index += 1
	var finished := step_index >= _mission.steps.size()
	if finished:
		status = Status.COMPLETE
	var credited := _commit(_mission.reward_rubles if finished else 0, completed_step)
	if credited < 0:
		step_index -= 1
		status = Status.ACTIVE
		_update_display()
		return
	if completed_step.cash_total > 0:
		var payable := completed_step.cash_total - completed_step.cash_share
		var receipt := "Получено %d руб. · Вам %d руб. · Баранову %d руб." % [completed_step.cash_total, credited, payable]
		if credited == 0:
			receipt = "Ваша доля уже зачислена · Баранову %d руб." % payable
		_hud.post_message("Расчёт с Фроловым", receipt, 4.0)
	if not finished:
		return
	var description := _mission.title
	if credited > 0:
		description += " · Награда: %d руб." % credited
	if _mission.unlocks_story_chapter > 0:
		description += " · Открыта глава II"
	_hud.post_message("ЗАДАНИЕ ВЫПОЛНЕНО", description)
	if not _next_missions.is_empty():
		_mission = _next_missions.pop_front()
		status = Status.AVAILABLE
		start()


func _on_player_death(_reason: StringName) -> void:
	_fail_active_mission()


func _fail_active_mission() -> void:
	if status == Status.ACTIVE:
		status = Status.FAILED
		_report_failure = true
		_commit()


func _current() -> Step:
	return _mission.steps[step_index]


func _target(step: Step) -> Node3D:
	return _world.get_node_or_null(step.target) as Node3D if not step.target.is_empty() else null


func _in_range(step: Step, target: Node3D) -> bool:
	return is_instance_valid(target) and not _player.is_dead \
			and _player.global_position.distance_squared_to(target.global_position) <= step.radius * step.radius


func _has_required_transport(step: Step) -> bool:
	if step.required_transport.is_empty():
		return true
	var vehicle := _world.get_node_or_null(step.required_transport)
	return is_instance_valid(vehicle) and _mounted_transport.is_valid() and _mounted_transport.call() == vehicle


func _can_interact() -> bool:
	if status != Status.ACTIVE or not _player.is_physics_processing():
		return false
	var step := _current()
	if step.kind != Step.Kind.INTERACT_NPC:
		return false
	if not step.inspection_subject.is_empty() and not _world.has_node(step.inspection_subject):
		return false
	var npc := _target(step) as CharacterBody3D
	return _in_range(step, npc) and (npc.is_in_group(&"street_citizens") or npc.is_in_group(&"story_contacts"))


func _clear_interaction(npc: Node3D) -> bool:
	var eye := Vector3.UP * 1.2
	var ray := PhysicsRayQueryParameters3D.create(_player.global_position + eye, npc.global_position + eye, 1,
			[_player.get_rid(), (npc as CharacterBody3D).get_rid()])
	return _world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func _update_display() -> void:
	if _marker:
		_marker.hide()
		_marker.queue_free()
		_marker = null
	_interaction = false
	match status:
		Status.AVAILABLE:
			if _start_after_opening:
				_hud.set_mission_status("", "")
			else:
				_hud.set_mission_status(_mission.title, "F4 — начать тестовое задание")
		Status.FAILED:
			_hud.set_mission_status(_mission.title, "F4 — повторить задание")
		Status.COMPLETE:
			_hud.set_mission_status("", "")
		Status.ACTIVE:
			var step := _current()
			_hud.set_mission_status(_mission.title, step.objective)
			var target := _target(step)
			if target:
				var above_target := step.kind in [Step.Kind.ENTER_TRANSPORT, Step.Kind.INTERACT_NPC]
				_marker = _build_marker(above_target, step.radius if step.kind in [Step.Kind.PARK_AND_EXIT, Step.Kind.CHASE] else 0.94)
				add_child(_marker)
				_marker.global_position = target.global_position


func _build_marker(above_target: bool, ring_radius: float) -> Node3D:
	var mark := Node3D.new()
	mark.name = "ObjectiveMarker"
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color("#ffcc4f")
	brass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mesh := MeshInstance3D.new()
	mesh.material_override = brass
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if above_target:
		var diamond := SphereMesh.new()
		diamond.radial_segments = 4
		diamond.rings = 2
		diamond.radius = 0.24
		diamond.height = 0.64
		mesh.mesh = diamond
		mesh.position.y = 2.6
	else:
		var ring := TorusMesh.new()
		ring.inner_radius = ring_radius - 0.16
		ring.outer_radius = ring_radius
		ring.rings = 28
		ring.ring_segments = 7
		mesh.mesh = ring
		mesh.position.y = 0.14
		var beam := MeshInstance3D.new()
		var column := CylinderMesh.new()
		column.height = 2.05
		column.top_radius = 0.62
		column.bottom_radius = 0.86
		column.radial_segments = 18
		beam.mesh = column
		beam.position.y = 1.15
		var glow := brass.duplicate() as StandardMaterial3D
		glow.albedo_color.a = 0.21
		glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		beam.material_override = glow
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mark.add_child(beam)
	mark.add_child(mesh)
	return mark


func _load_progress() -> void:
	var file := ConfigFile.new()
	if file.load(save_path) != OK:
		return
	var saved := int(file.get_value(_mission.id, "status", Status.AVAILABLE))
	var stage := int(file.get_value(_mission.id, "stage", 0))
	if saved in [Status.ACTIVE, Status.FAILED] and stage >= 0 and stage < _mission.steps.size():
		status = saved as Status
		step_index = stage
	elif saved == Status.COMPLETE:
		status = Status.COMPLETE
		step_index = _mission.steps.size()


func _commit(reward_rubles := 0, completed_step: Step = null) -> int:
	var file := ConfigFile.new()
	var load_error := file.load(save_path)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		push_warning("Не удалось прочитать сохранение заданий (%d)" % load_error)
		return -1
	_migrate_receipts(file)
	file.set_value(_mission.id, "status", status)
	file.set_value(_mission.id, "stage", step_index)
	if _story:
		file.set_value("campaign", "current_mission", _mission.id)
	var credited := Wallet.credit_once(file, _mission.id + "/completion", reward_rubles)
	if completed_step and completed_step.cash_total > 0:
		credited += Wallet.credit_once(file, _mission.id + "/sale", completed_step.cash_share)
		file.set_value(_mission.id, "rubles_for_baranov", completed_step.cash_total - completed_step.cash_share)
	if completed_step and completed_step.settles_payment:
		file.set_value(_mission.id, "rubles_for_baranov", 0)
	if status == Status.COMPLETE and _mission.unlocks_chapter > 0:
		var unlocked := int(file.get_value("campaign", "unlocked_chapter", 1))
		file.set_value("campaign", "unlocked_chapter", maxi(unlocked, _mission.unlocks_chapter))
	if status == Status.COMPLETE and _mission.unlocks_story_chapter > 0:
		var chapter := int(file.get_value("campaign", "story_chapter", 1))
		file.set_value("campaign", "story_chapter", maxi(chapter, _mission.unlocks_story_chapter))
	var error := Wallet.save(file, save_path)
	if error != OK:
		push_warning("Не удалось сохранить прогресс задания (%d)" % error)
		return -1
	_hud.set_wallet_balance(Wallet.balance(file))
	_publish_objective()
	return credited


func _publish_objective() -> void:
	objective_changed.emit(_mission.id, _current() if status == Status.ACTIVE else null)
	_update_display()


func _migrate_receipts(file: ConfigFile) -> void:
	# Older saves already included these completion rewards in the wallet balance.
	for id in ["again_twenty_five", "wonder_on_wheels"]:
		var receipt: String = id + "/completion"
		if file.get_value(id, "status", Status.AVAILABLE) == Status.COMPLETE and not file.has_section_key("wallet_receipts", receipt):
			file.set_value("wallet_receipts", receipt, true)
