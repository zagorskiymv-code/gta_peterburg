extends CharacterBody3D

const Wardrobe = preload("res://scripts/npc/citizen_wardrobe.gd")
const Geometry = preload("res://scripts/world/district_geometry.gd")
const Materials = preload("res://scripts/player/character_materials.gd")
const Visual = preload("res://scripts/player/historical_character_visual.gd")

@onready var visual: Visual = $CharacterVisual


func _ready() -> void:
	Wardrobe.new().dress(visual, Wardrobe.Outfit.MERCHANT, Wardrobe.Hat.BOWLER,
			Color("#292629"), Color("#825434"), Color("#383137"))
	visual.scale = Vector3(1.18, 1.02, 1.13)
	var torso := visual.upper_body.get_node("CoatTorso") as MeshInstance3D
	torso.scale *= Vector3(1.12, 1.0, 1.25)
	var tails := visual.body.get_node("CoatSkirts") as MeshInstance3D
	tails.scale *= Vector3(0.79, 1.0, 0.64)
	var vest := visual.upper_body.get_node("Waistcoat") as MeshInstance3D
	vest.position.z -= 0.025
	vest.scale.x *= 1.12
	for arm in visual.arms:
		arm.position.x *= 1.12
	var hair := Materials.get_material(Color("#4c3429"), Materials.Finish.HAIR)
	var moustache := visual.head.get_node("Moustache") as MeshInstance3D
	moustache.scale *= Vector3(1.48, 1.16, 1.22)
	moustache.material_override = hair
	visual.head.get_node("Hair").material_override = hair
	var beard := SphereMesh.new()
	beard.radial_segments = 9
	beard.rings = 5
	beard.radius = 0.5
	beard.height = 1.0
	var chin := Geometry.mesh_part(visual.head, "FullBeard", Vector3(0, 0.080, -0.077), beard, hair)
	chin.scale = Vector3(0.148, 0.120, 0.102)
	for side in [-1.0, 1.0]:
		var sideburn := Geometry.mesh_part(visual.head, "Sideburn", Vector3(side * 0.067, 0.126, -0.026), beard, hair)
		sideburn.scale = Vector3(0.039, 0.091, 0.13)
