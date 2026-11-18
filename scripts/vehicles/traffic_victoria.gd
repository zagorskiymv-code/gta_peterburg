extends Node3D

const Model = preload("res://scripts/vehicles/victoria_model.gd")
const Visual = preload("res://scripts/player/historical_character_visual.gd")
const Wardrobe = preload("res://scripts/npc/citizen_wardrobe.gd")
const DRIVER := preload("res://scenes/player/historical_character_visual.tscn")

var paint_index := 0
var costume_index := 0

var _model: Model
var _driver: Visual
var _previous: Vector3
var _heading := 0.0
var _steer := 0.0


func _ready() -> void:
	_model = Model.new()
	_model.name = "VictoriaModel"
	add_child(_model)
	_model.set_paint(paint_index)

	_driver = DRIVER.instantiate()
	_driver.name = "NPCDriver"
	add_child(_driver)
	_driver.position = Model.DRIVER_SEAT
	var outfits := [Wardrobe.Outfit.CLERK, Wardrobe.Outfit.MERCHANT, Wardrobe.Outfit.WORKER,
			Wardrobe.Outfit.ELDER, Wardrobe.Outfit.CLERK, Wardrobe.Outfit.MERCHANT]
	Wardrobe.new().dress(_driver, outfits[costume_index % outfits.size()], -1,
			Color.TRANSPARENT, Color.TRANSPARENT, Color.TRANSPARENT)
	_driver.pose_seated()
	for mesh: MeshInstance3D in _driver.find_children("*", "MeshInstance3D", true, false):
		if mesh.name not in [&"CoatShoulders", &"CoatTorso", &"Skull", &"BowlerCrown", &"CapCrown"]:
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_previous = global_position
	_heading = global_rotation.y


func _physics_process(delta: float) -> void:
	var distance := _previous.distance_to(global_position)
	var heading := global_rotation.y
	var yaw := angle_difference(_heading, heading)
	var target := atan((Model.REAR_AXLE - Model.FRONT_AXLE) * yaw / distance) if distance > 0.002 else 0.0
	_steer = lerpf(_steer, clampf(target, -0.57, 0.57), 1.0 - exp(-delta * 8.0))
	_model.animate_running_gear(distance, _steer)
	_driver.pose_seated(_steer)
	_previous = global_position
	_heading = heading
