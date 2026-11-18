extends Node3D

const Citizen = preload("res://scripts/npc/citizen_npc.gd")
const Wardrobe = preload("res://scripts/npc/citizen_wardrobe.gd")
const CITIZEN_SCENE := preload("res://scenes/npc/citizen_npc.tscn")

# Local coordinates relative to PalaceSquare (17, 0, -222).
# Foot traffic stays outside the column's central esplanade and the axis of the Staff arch.
func _ready() -> void:
	var nobles := Node3D.new()
	nobles.name = "Nobles"
	add_child(nobles)
	var soldiers := Node3D.new()
	soldiers.name = "Soldiers"
	add_child(soldiers)

	_place(nobles, "WesternStroller", Wardrobe.Outfit.FROCK_COAT, Vector2(-42, -21), 20,
			[Vector2(-42, -21), Vector2(-42, -11), Vector2(-38, -9), Vector2(-38, -18)], 1.22, 2.8)
	_place(nobles, "WestPromenadeLady", Wardrobe.Outfit.LADY_IN_DRESS, Vector2(-31, 0), 0,
			[Vector2(-31, 0), Vector2(-33, 9), Vector2(-36, 12), Vector2(-35, 4)], 1.05, 4.1)
	_place(nobles, "EasternStroller", Wardrobe.Outfit.OVERCOAT, Vector2(41, -18), 170,
			[Vector2(41, -18), Vector2(42, -10), Vector2(38, -8), Vector2(37, -17)], 1.15, 3.6)
	_place(nobles, "EastPromenadeLady", Wardrobe.Outfit.LADY_IN_CAPE, Vector2(38, 2), 165,
			[Vector2(38, 2), Vector2(38, 13), Vector2(34, 12), Vector2(34, 4)], 0.98, 2.0)
	_place(nobles, "ConversationLady", Wardrobe.Outfit.LADY_IN_DRESS, Vector2(-39.4, -0.5), -87,
			[], 1.05, 3.0, Color("#7c5054"))
	_place(nobles, "ConversationGentleman", Wardrobe.Outfit.OVERCOAT, Vector2(-38.15, -0.55), 94,
			[], 1.15, 3.0, Color("#4d4b42"))

	_place(soldiers, "WinterPalaceWestSentry", Wardrobe.Outfit.SENTRY, Vector2(-4.65, -34.3), 170)
	_place(soldiers, "WinterPalaceEastSentry", Wardrobe.Outfit.SENTRY, Vector2(4.65, -34.3), -170)
	_place(soldiers, "GeneralStaffSentry", Wardrobe.Outfit.SENTRY, Vector2(15.4, 24.5), 8)
	_place(soldiers, "WestForecourtPatrol", Wardrobe.Outfit.PATROLMAN, Vector2(-30, -28), -90,
			[Vector2(-30, -28), Vector2(-11, -28)], 1.25, 1.0)
	_place(soldiers, "EastForecourtPatrol", Wardrobe.Outfit.PATROLMAN, Vector2(29, -28), 90,
			[Vector2(29, -28), Vector2(11, -28)], 1.25, 1.0)

	_place(nobles, "PalaceLateralLady", Wardrobe.Outfit.LADY_IN_CAPE, Vector2(-41, -31), -90,
			[Vector2(-41,-31), Vector2(-33,-31)], 1.04, 3.4)
	_place(nobles, "WesternPromenadeGentleman", Wardrobe.Outfit.OVERCOAT, Vector2(-45, 6), 180,
			[Vector2(-45,6), Vector2(-45,15), Vector2(-42,17)], 1.10, 3.9, Color("#50495a"))
	_place(nobles, "EasternPromenadeLady", Wardrobe.Outfit.LADY_IN_DRESS, Vector2(46, 16), 180,
			[Vector2(46,16), Vector2(47,8)], 0.96, 3.2, Color("#70485d"))
	_place(nobles, "EastForecourtGentleman", Wardrobe.Outfit.FROCK_COAT, Vector2(32, -33), 90,
			[Vector2(32,-33), Vector2(24,-33)], 1.16, 4.0)
	_place(nobles, "PalaceEastVisitor", Wardrobe.Outfit.OVERCOAT, Vector2(44.5, -24), -135,
			[], 1.15, 3.0, Color("#5c5240"))
	_place(nobles, "PalaceEastCompanion", Wardrobe.Outfit.LADY_IN_DRESS, Vector2(46.0, -24.2), 65,
			[], 1.01, 3.0, Color("#5c687f"))

	_place(soldiers, "GeneralStaffWestSentry", Wardrobe.Outfit.SENTRY, Vector2(-1.8, 24.5), -8)
	_place(soldiers, "ForecourtWestSentry", Wardrobe.Outfit.SENTRY, Vector2(-30, -34.5), 178)


func _place(group: Node3D, label: String, outfit: Wardrobe.Outfit, site: Vector2, yaw: float,
		points: Array[Vector2] = [], speed := 1.15, dwell := 2.0, coat := Color.TRANSPARENT) -> void:
	var npc: Citizen = CITIZEN_SCENE.instantiate()
	npc.name = label
	npc.position = Vector3(site.x, 0.10, site.y)
	npc.rotation_degrees.y = yaw
	npc.citizen_type = Citizen.CitizenType.NOBLE if group.name == "Nobles" else Citizen.CitizenType.SOLDIER
	npc.outfit = outfit
	npc.coat_color = coat
	npc.activity_radius = 100.0
	npc.crowd_lod = true
	npc.walk_speed = speed
	npc.wait_time = dwell
	if not points.is_empty():
		var path := Path3D.new()
		path.name = label + "Route"
		path.curve = Curve3D.new()
		for point in points:
			path.curve.add_point(Vector3(point.x, 0.015, point.y))
		$Routes.add_child(path)
		npc.route = path
	group.add_child(npc)
