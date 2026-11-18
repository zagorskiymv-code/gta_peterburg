extends CharacterBody3D

enum State { IDLE, WALK, WAIT, LOOK_AROUND, TALK }
enum CitizenType { RESIDENT, NOBLE, SOLDIER }
enum Headwear { TYPE_DEFAULT, BOWLER, CAP, BARE }

const Wardrobe = preload("res://scripts/npc/citizen_wardrobe.gd")
const CharacterVisual = preload("res://scripts/player/historical_character_visual.gd")
const WAYPOINT_TOLERANCE := 0.10
const AVOIDANCE_DISTANCE := 0.55
const STALL_SECONDS := 2.0
const TALK_DISTANCE := 2.35
const SHADOW_SILHOUETTE := {
	&"CoatShoulders": true, &"CoatTorso": true, &"CoatHem": true, &"CoatSkirts": true,
	&"LongSkirt": true, &"ShoulderCape": true, &"Skull": true, &"BowlerCrown": true,
	&"SilkTopHat": true, &"CapCrown": true, &"UpperSleeve": true, &"ForeSleeve": true,
	&"Thigh": true, &"TrouserLeg": true, &"BootShaft": true, &"BootUpper": true,
}

@export var citizen_type := CitizenType.RESIDENT
@export_range(0.2, 3.5, 0.05, "suffix:m/s") var walk_speed := 1.45
@export_range(0.5, 30.0, 0.5, "suffix:rad/s") var turn_speed := 5.0
## Zero keeps the NPC active at any distance.
@export_range(0.0, 150.0, 1.0, "suffix:m") var activity_radius := 28.0
## Ordered points in world space via Path3D transforms. The last point links back to the first.
## Leave empty for a stationary NPC.
@export var route: Path3D
@export_range(0.0, 60.0, 0.1, "suffix:s") var wait_time := 2.0

@export_group("Appearance")
@export var outfit := Wardrobe.Outfit.DEFAULT
@export var headwear := Headwear.TYPE_DEFAULT
## An alpha of zero uses the clothing palette for the selected citizen type.
@export var coat_color := Color.TRANSPARENT
@export var waistcoat_color := Color.TRANSPARENT
@export var trousers_color := Color.TRANSPARENT

@onready var visual: CharacterVisual = $CharacterVisual

# Populations opt into distance tiers. Bodies and visuals remain in the tree in every tier.
var crowd_lod := false
var variation_seed := 0
var _lod_sleeping := false
var _shadow_meshes: Array[MeshInstance3D] = []
var _shadow_enabled := true
var _animation_time := 0.0
var _animation_travel := Vector3.ZERO
var struck_down := false
var _launched := false
var state := State.IDLE
var _waypoint := 0
var _wait_remaining := 0.0
var _observer: Node3D
var _rng := RandomNumberGenerator.new()
var _pace := 1.0
var _direction := 1
var _last_stop := -1
var _laps := 0
var _stalled := 0.0
var _idle_check := 1.0
var _attention_time := 0.0
var _talk_cooldown := 0.0
var _recovery_cooldown := 0.0
var _head_target := 0.0
var _head_yaw := 0.0
var _partner: CharacterBody3D
var _probe := KinematicCollision3D.new()
var stride_scale := 1.0


func _ready() -> void:
	_observer = get_tree().get_first_node_in_group(&"district_explorer") as Node3D
	add_to_group(&"street_citizens")
	_rng.seed = hash(str(get_path()))
	_pace = _rng.randf_range(0.97, 1.06)
	_idle_check = _rng.randf_range(0.3, 2.4)
	_wait_remaining = wait_time
	visual.breath = fposmod(global_position.x * 0.73 + global_position.z * 0.43, TAU)
	var selected := outfit
	if selected == Wardrobe.Outfit.DEFAULT:
		selected = [Wardrobe.Outfit.WORKER, Wardrobe.Outfit.OVERCOAT, Wardrobe.Outfit.SENTRY][citizen_type]
	if variation_seed != 0:
		_vary_clothes(selected)
	var hat := -1 if headwear == Headwear.TYPE_DEFAULT else headwear - 1
	stride_scale = Wardrobe.new().dress(visual, selected, hat, coat_color, waistcoat_color, trousers_color)
	if crowd_lod:
		for mesh: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
			if mesh.visible and mesh.name in SHADOW_SILHOUETTE:
				_shadow_meshes.append(mesh)
			else:
				mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var capsule := $CollisionShape3D.shape.duplicate() as CapsuleShape3D
	capsule.height *= visual.scale.y
	$CollisionShape3D.shape = capsule
	$CollisionShape3D.position.y = capsule.height * 0.5


func _physics_process(delta: float) -> void:
	if _launched:
		_advance_impact_flight(delta)
		return
	var distance := global_position.distance_to(_observer.global_position) if is_instance_valid(_observer) else 0.0
	var active := _is_active()
	if crowd_lod:
		var use_shadows := distance < (36.0 if _shadow_enabled else 29.0)
		if use_shadows != _shadow_enabled:
			_shadow_enabled = use_shadows
			for mesh in _shadow_meshes:
				mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if use_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if crowd_lod and activity_radius > 0.0:
		_lod_sleeping = distance > (60.0 if _lod_sleeping else 68.0)
		active = active and not _lod_sleeping
	_talk_cooldown = maxf(0.0, _talk_cooldown - delta)
	_recovery_cooldown = maxf(0.0, _recovery_cooldown - delta)
	var motion := _choose_motion(delta) if active else Vector3.ZERO
	if not active:
		_end_talk()
		state = State.IDLE
		if is_on_floor() and visual.pose == CharacterVisual.Pose.IDLE and visual.movement_blend <= 0.01:
			_animation_time = 0.0
			_animation_travel = Vector3.ZERO
			return
	velocity.x = motion.x
	velocity.z = motion.z
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()
	if active and state == State.WALK:
		var traveled := get_position_delta().dot(motion.normalized())
		_stalled = 0.0 if traveled >= delta * 0.16 else _stalled + delta
	if active and _recovery_cooldown <= 0.0 and (_stalled >= STALL_SECONDS or global_position.y < -0.6):
		_recover_route()
	if active or visual.pose != CharacterVisual.Pose.IDLE or visual.movement_blend > 0.01 or not is_on_floor():
		if state == State.TALK and is_instance_valid(_partner):
			_face(_partner.global_position - global_position, delta)
		elif not motion.is_zero_approx():
			_face(motion, delta)
		_animation_time += delta
		_animation_travel += get_position_delta()
		var interval := 0.0
		if crowd_lod and activity_radius > 0.0:
			interval = 1.0 / 15.0 if distance > 43.0 else (1.0 / 30.0 if distance > 26.0 else 0.0)
		if _animation_time >= interval:
			visual.animate(_animation_time, _animation_travel, Vector3.ZERO, is_on_floor(),
					get_floor_normal() if is_on_floor() else Vector3.UP, velocity.y, false, stride_scale)
			_animate_attention(_animation_time)
			_animation_time = 0.0
			_animation_travel = Vector3.ZERO


func _choose_motion(delta: float) -> Vector3:
	if is_instance_valid(_partner):
		_attention_time -= delta
		_wait_remaining = maxf(_wait_remaining - delta, 0.0)
		var gap := global_position.distance_to(_partner.global_position)
		if _attention_time > 0.0 and gap >= 0.85 and gap <= TALK_DISTANCE and _partner._partner == self:
			state = State.TALK
			return Vector3.ZERO
		_end_talk()

	var routed := _has_route()
	if not routed or _wait_remaining > 0.0:
		_wait_remaining = maxf(_wait_remaining - delta, 0.0)
		_update_pause(delta, routed)
		return Vector3.ZERO

	_waypoint = posmod(_waypoint, route.curve.point_count)
	var offset := (_route_point(_waypoint) - global_position).slide(Vector3.UP)
	var distance := offset.length()
	if distance <= WAYPOINT_TOLERANCE:
		_arrive()
		return Vector3.ZERO

	state = State.WALK
	var heading := offset / distance
	var look_ahead := minf(AVOIDANCE_DISTANCE, distance)
	if test_move(global_transform, heading * look_ahead, _probe, 0.01):
		var collider := _probe.get_collider()
		if collider is CharacterBody3D:
			# Keep to the verified route and yield rather than stepping into the road or water.
			state = State.WAIT
			_stalled += delta
			return Vector3.ZERO
	return heading * minf(walk_speed * _pace, distance / delta)


func _arrive() -> void:
	_last_stop = _waypoint
	_stalled = 0.0
	# Vary the order at the first stop, after completing a circuit. Both directions use the same verified segments.
	if _waypoint == 0 and route.curve.point_count > 2 and citizen_type != CitizenType.SOLDIER:
		_laps += 1
		if _laps > 1 and (_laps % 3 == 0 or _rng.randf() < 0.24):
			_direction = -_direction
	_waypoint = posmod(_waypoint + _direction, route.curve.point_count)
	if citizen_type == CitizenType.SOLDIER:
		_wait_remaining = clampf(wait_time + _rng.randf_range(0.9, 1.4), 2.0, 8.0)
	else:
		var visit := _rng.randf_range(-0.9, 2.2)
		if _rng.randf() < 0.20:
			visit += 2.4
		_wait_remaining = clampf(wait_time + visit, 2.0, 8.0)
	_idle_check = _rng.randf_range(0.18, 0.8)
	state = State.WAIT


func _update_pause(delta: float, routed: bool) -> void:
	_attention_time = maxf(0.0, _attention_time - delta)
	state = State.WAIT if routed else State.IDLE
	if citizen_type == CitizenType.SOLDIER:
		return
	if _attention_time > 0.0:
		state = State.LOOK_AROUND
		return
	_idle_check -= delta
	if _idle_check > 0.0:
		return
	_idle_check = _rng.randf_range(2.2, 5.0)
	if not _try_talk() and _rng.randf() < 0.78:
		_head_target = _rng.randf_range(0.16, 0.42) * (-1 if _rng.randf() < 0.5 else 1)
		_attention_time = _rng.randf_range(0.8, 2.0)
		state = State.LOOK_AROUND


func _try_talk() -> bool:
	if _talk_cooldown > 0.0:
		return false
	for candidate in get_tree().get_nodes_in_group(&"street_citizens"):
		if candidate == self or candidate.citizen_type == CitizenType.SOLDIER or is_instance_valid(candidate._partner):
			continue
		if candidate._talk_cooldown > 0.0 or candidate.state == State.WALK or not candidate.is_on_floor() or not candidate._is_active() or candidate._lod_sleeping:
			continue
		# Moving NPCs can meet while paused at a checkpoint. A yielding NPC is still in transit.
		if candidate._has_route() and candidate._wait_remaining < 0.9:
			continue
		var separation := global_position.distance_squared_to(candidate.global_position)
		if separation < 1.05 * 1.05 or separation > TALK_DISTANCE * TALK_DISTANCE:
			continue
		var eye := Vector3.UP * 1.25
		var ray := PhysicsRayQueryParameters3D.create(global_position + eye, candidate.global_position + eye, 1)
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		var duration := _rng.randf_range(2.4, 4.6)
		_partner = candidate
		_attention_time = duration
		state = State.TALK
		candidate._partner = self
		candidate._attention_time = duration
		candidate.state = State.TALK
		return true
	return false


func _end_talk() -> void:
	if not is_instance_valid(_partner):
		_partner = null
		return
	var other := _partner
	_partner = null
	_attention_time = 0.0
	_talk_cooldown = _rng.randf_range(9.0, 15.0)
	_idle_check = _rng.randf_range(0.8, 2.0)
	if other._partner == self:
		other._partner = null
		other._attention_time = 0.0
		other._talk_cooldown = other._rng.randf_range(9.0, 15.0)
		other._idle_check = other._rng.randf_range(0.8, 2.0)


func _animate_attention(delta: float) -> void:
	var target := 0.0
	if state == State.LOOK_AROUND:
		target = _head_target * smoothstep(0.0, 0.38, _attention_time)
	elif state == State.TALK:
		target = sin(visual.breath * 1.8) * 0.055
		visual.head.rotation.x = sin(visual.breath * 2.1) * 0.085
	else:
		visual.head.rotation.x = move_toward(visual.head.rotation.x, 0.0, delta * 0.9)
	_head_yaw = move_toward(_head_yaw, target, delta * 0.95)
	visual.head.rotation.y += _head_yaw


func _recover_route() -> void:
	_stalled = 0.0
	_recovery_cooldown = 0.22
	if not _has_route():
		return
	var candidates := [_waypoint]
	if _last_stop >= 0 and _last_stop < route.curve.point_count:
		candidates.append(_last_stop)
	candidates.sort_custom(func(a: int, b: int) -> bool:
		return global_position.distance_squared_to(_route_point(a)) < global_position.distance_squared_to(_route_point(b)))
	for index: int in candidates:
		var floor_position := _safe_floor(_route_point(index))
		if not floor_position.is_finite():
			continue
		var motion := (floor_position - global_position).slide(Vector3.UP)
		if is_on_floor() and not test_move(global_transform, motion):
			if index == _last_stop and citizen_type != CitizenType.SOLDIER:
				_direction = -_direction
			_waypoint = index
			return

	# Recover a fallen or completely wedged NPC only when both ends are outside the player's view.
	var camera := get_viewport().get_camera_3d()
	if not camera or not is_instance_valid(_observer):
		return
	for index: int in candidates:
		var floor_position := _safe_floor(_route_point(index))
		if not floor_position.is_finite():
			continue
		if _can_player_see(camera, global_position) or _can_player_see(camera, floor_position):
			continue
		global_position = floor_position + Vector3.UP * 0.035
		velocity = Vector3.ZERO
		reset_physics_interpolation()
		_waypoint = index
		_wait_remaining = 2.0
		return


func _can_player_see(camera: Camera3D, site: Vector3) -> bool:
	if site.distance_squared_to(_observer.global_position) < 19.0 * 19.0:
		return true
	for height in [0.0, 1.0, 1.9]:
		if camera.is_position_in_frustum(site + Vector3.UP * height):
			return true
	return false


func _safe_floor(site: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(site + Vector3.UP * 0.23, site - Vector3.UP * 0.18, 1)
	var floor_hit := space.intersect_ray(ray)
	if floor_hit.is_empty() or floor_hit.normal.y < 0.7:
		return Vector3.INF
	var shape: CollisionShape3D = $CollisionShape3D
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape.shape
	query.transform.origin = floor_hit.position + Vector3.UP * (shape.position.y + 0.04)
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	if not space.intersect_shape(query, 1).is_empty():
		return Vector3.INF
	return floor_hit.position


func _is_active() -> bool:
	if struck_down:
		return false
	return activity_radius <= 0.0 or not is_instance_valid(_observer) \
			or global_position.distance_squared_to(_observer.global_position) <= activity_radius * activity_radius


func _has_route() -> bool:
	return is_instance_valid(route) and route.curve != null and route.curve.point_count >= 2


func _route_point(index: int) -> Vector3:
	return route.to_global(route.curve.get_point_position(index))


func _face(direction: Vector3, delta: float) -> void:
	var parent_3d := get_parent_node_3d()
	var parent_yaw := parent_3d.global_rotation.y if parent_3d else 0.0
	rotation.y = rotate_toward(rotation.y, atan2(-direction.x, -direction.z) - parent_yaw, turn_speed * delta)


func _vary_clothes(selected: Wardrobe.Outfit) -> void:
	var palette: Array = Wardrobe.PRESETS[selected]
	var tones := [Color("#7d594f"), Color("#455867"), Color("#526251"), Color("#60525e"), Color("#85735a")]
	var tint: Color = tones[variation_seed % tones.size()]
	if coat_color.a == 0.0:
		coat_color = Color(palette[3]).lerp(tint, 0.58)
	if waistcoat_color.a == 0.0:
		waistcoat_color = Color(palette[4]).lerp(tint.lightened(0.15), 0.30)
	if trousers_color.a == 0.0:
		trousers_color = Color(palette[5]).lerp(tint.darkened(0.29), 0.38)


func fall_after_vehicle_impact(direction: Vector3) -> void:
	if not _begin_impact(direction):
		return
	set_physics_process(false)
	set_deferred("collision_mask", 0)
	var fall := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	fall.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(visual, "rotation:x", -PI / 2.0, 0.29)
	fall.parallel().tween_property(visual, "position:y", 0.16, 0.29)
	fall.tween_interval(7.0)
	fall.tween_callback(queue_free)


func launch_from_horse(direction: Vector3, horse: PhysicsBody3D) -> void:
	if not _begin_impact(direction):
		return
	add_collision_exception_with(horse)
	# Keep world collisions during flight so the character cannot fly through a building.
	collision_mask = 1
	velocity = direction * 24.0 + Vector3.UP * 6.5
	_launched = true


func _begin_impact(direction: Vector3) -> bool:
	if struck_down:
		return false
	struck_down = true
	_end_talk()
	remove_from_group(&"street_citizens")
	set_deferred("collision_layer", 0)
	velocity = Vector3.ZERO
	visual.leave_seat()
	rotation.y = atan2(-direction.x, -direction.z)
	visual.rotation = Vector3.ZERO
	return true


func _advance_impact_flight(delta: float) -> void:
	velocity += get_gravity() * delta
	move_and_slide()
	visual.rotation.x = move_toward(visual.rotation.x, -PI / 2.0, delta * 3.1)
	visual.position.y = move_toward(visual.position.y, 0.16, delta * 0.55)
	if global_position.y < -12.0:
		queue_free()
	elif is_on_floor():
		_launched = false
		velocity = Vector3.ZERO
		visual.rotation.x = -PI / 2.0
		visual.position.y = 0.16
		set_physics_process(false)
		get_tree().create_timer(7.0, false, true).timeout.connect(queue_free)
