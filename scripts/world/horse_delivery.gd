extends Node3D

const Step = preload("res://scripts/systems/mission_step.gd")
const Horse = preload("res://scripts/vehicles/riding_horse.gd")
const HorseVisual = preload("res://scripts/vehicles/horse_visual.gd")
const Character := preload("res://scenes/player/historical_character_visual.tscn")
const Wardrobe = preload("res://scripts/npc/citizen_wardrobe.gd")
const Geometry = preload("res://scripts/world/district_geometry.gd")

var _horse: Horse
var _origin: Transform3D


func build(stable: Node3D) -> void:
	_contact("Stablehand", stable.to_global(Vector3(3.0, -0.009, 6.2)), PI, Wardrobe.Outfit.WORKER)
	_contact("Frolov", Vector3(31.4, 0.025, 105.8), PI * 0.5, Wardrobe.Outfit.MERCHANT)
	Geometry.group(self, "Handover", Vector3(28.5, 0.025, 105.8))
	_origin = Transform3D(Basis(Vector3.UP, PI), stable.to_global(Vector3(0, -0.085, 7.2)))


func _contact(label: String, at: Vector3, yaw: float, outfit: Wardrobe.Outfit) -> void:
	var contact := CharacterBody3D.new()
	contact.name = label
	contact.position = at
	contact.rotation.y = yaw
	contact.collision_layer = 4
	contact.collision_mask = 1
	contact.add_to_group(&"story_contacts")
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.76
	collision.shape = capsule
	collision.position.y = 0.88
	contact.add_child(collision)
	var visual := Character.instantiate()
	contact.add_child(visual)
	add_child(contact)
	var coat := Color("#433342") if outfit == Wardrobe.Outfit.MERCHANT else Color.TRANSPARENT
	Wardrobe.new().dress(visual, outfit, -1, coat, Color.TRANSPARENT, Color.TRANSPARENT)


func objective_changed(mission_id: String, step: Step) -> void:
	if mission_id == "a_profitable_deal" and step and not step.inspection_subject.is_empty():
		if not is_instance_valid(_horse):
			var at: Vector3 = $Handover.global_position + Vector3.UP * 0.02
			_prepare_horse(Transform3D(Basis.IDENTITY, at))
		_horse.held_for_handover = true
		_horse.mount_allowed = false
		return
	if mission_id != "a_horse_not_a_bicycle":
		return
	if step and step.kind == Step.Kind.INTERACT_NPC:
		if is_instance_valid(_horse):
			_horse.mount_allowed = false
			_horse.hide()
			_horse.process_mode = Node.PROCESS_MODE_DISABLED
		return
	if step and step.kind == Step.Kind.ENTER_TRANSPORT:
		_prepare_horse(_origin)
	elif not step and is_instance_valid(_horse):
		_horse.mount_allowed = false


func _prepare_horse(place: Transform3D) -> void:
	if not is_instance_valid(_horse):
		_horse = Horse.new()
		_horse.name = "DeliveryHorse"
		_horse.delivery_mount = true
		var model := HorseVisual.new()
		_horse.horse = model
		_horse.add_child(model)
		var saddle := Geometry.solid_material(Color("#4c3426"))
		var blanket := Geometry.solid_material(Color("#69403b"))
		Geometry.box(model, "SaddleBlanket", Vector3(0, 1.60, 0.01), Vector3(0.54, 0.07, 0.51), blanket)
		Geometry.box(model, "Saddle", Vector3(0, 1.665, 0.02), Vector3(0.39, 0.11, 0.40), saddle)
		add_child(_horse)
		_horse.rider_lost.connect(get_parent().get_node("PlayerSpawn/Player").die)
	_horse.global_transform = place
	_horse.held_for_handover = false
	_horse.velocity = Vector3.ZERO
	_horse.reset_physics_interpolation()
	_horse.mount_allowed = true
	_horse.process_mode = Node.PROCESS_MODE_INHERIT
	_horse.show()
