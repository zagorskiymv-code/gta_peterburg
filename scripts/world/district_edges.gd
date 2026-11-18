@tool
extends RefCounted

const G = preload("res://scripts/world/district_geometry.gd")

var brick := G.solid_material(Color("#927264"))
var plaster := G.solid_material(Color("#ad9b86"))
var granite := G.solid_material(Color("#8b8276"))
var coping := G.solid_material(Color("#b6aa98"))
var iron := G.solid_material(Color("#3c4741"))
var timber := G.solid_material(Color("#75604a"))
var unit_box := BoxMesh.new()

const WORKS_NOTICE := "ПРОХОДЪ ЗАКРЫТЪ\nПРОИЗВОДЯТСЯ РАБОТЫ"


func build(parent: Node3D, paving: Material, flagstone: Material) -> void:
	var edges := G.group(parent, "DistrictEdges")

	# The cross street meets a service gate on the east and turns onto the quay in the west.
	var east := G.group(edges, "East", Vector3(89.65, 0, 0))
	east.rotation.y = -PI / 2.0
	var ends := [-290.0, -255.4, -247.4, -32.0, -22.0, 90.0]
	for i in [0, 2, 4]:
		_wall(east, ends[i], ends[i + 1], plaster if i == 2 else brick)
	_gate(east, "MillionnayaWorks", -251.4, 8.0, WORKS_NOTICE)
	_gate(east, "CrossStreetGate", -27.0, 10.0)
	# Local +Z points into the district on the east edge.
	_tile(east, "CrossStreetSeam", -32, -22, -0.6, 5.1, 0.004, paving)
	_tile(east, "MillionnayaSeam", -255.4, -247.4, -0.6, 2.0, 0.037, paving)

	var north := G.group(edges, "North", Vector3(0, 0, -289.65))
	_wall(north, -90, -43, brick)
	_gate(north, "ServiceCourtyardGate", -39, 8, "СЛУЖЕБНЫЙ ДВОРЪ")
	_wall(north, -35, 90, plaster)
	_tile(north, "ServiceLane", -42, -35, -0.7, 5.1, 0.008, paving)

	var south := G.group(edges, "South", Vector3(0, 0, 89.65))
	_wall(south, -90, -57, brick)
	_gate(south, "WorkshopYard", -52.5, 9, "СТОЛЯРНЫЯ МАСТЕРСКІЯ")
	_wall(south, -48, -4, brick)
	_gate(south, "MainStreetGate", 0, 8)
	_tile(south, "MainStreetSeam", -4, 4, -13.75, 0.65, 0.004, paving)
	_tile(south, "WestWalk", -7, -4, -13.75, 0.55, 0.066, flagstone)
	_tile(south, "EastWalk", 4, 7, -13.75, 0.55, 0.066, flagstone)
	_tile(south, "WorkshopLane", -56, -49, -4.5, 0.65, 0.008, paving)

	# The island bridge remains open. Both returns stand on a full-depth quay face.
	_quay(south, "HollandWestReturn", 4, 23.86, 0.0)
	_quay(south, "HollandEastReturn", 29.14, 48.0, 0.0)
	_wall(south, 62.0, 67.5, brick)
	_gate(south, "OuterQuayWorks", 71.0, 7.0, WORKS_NOTICE)
	_wall(south, 74.5, 90.0, plaster)
	_tile(south, "OuterQuaySeam", 67.5, 74.5, -6.0, 0.65, 0.027, paving)

	var west := G.group(edges, "WestQuay", Vector3(-89.65, 0, 0))
	west.rotation.y = PI / 2.0
	# Along this edge local X is -world Z. Existing bridge and bypass returns stay in place.
	_quay(west, "SouthReach", -90, 94, 0.0)
	_quay(west, "NorthReach", 226.7, 290, 0.0)
	_tile(west, "WestPromenade", -90, 94, -2.7, 0.25, 0.016, flagstone)
	_tile(west, "CrossStreetQuayJunction", 22, 32, -13, -2.69, 0.004, paving)
	_tile(west, "NorthPromenade", 226.7, 290, -1.95, 0.24, 0.016, flagstone)


func _wall(parent: Node3D, first: float, last: float, material: Material) -> void:
	var span := last - first
	var x := (first + last) * 0.5
	G.box(parent, "CourtyardMasonry", Vector3(x, 1.18, 0), Vector3(span, 2.5, 0.62), material, true)
	G.box(parent, "WallCoping", Vector3(x, 2.48, 0), Vector3(span, 0.17, 0.78), coping)
	var piers: Array[Transform3D] = []
	var count := ceili(span / 8.0)
	for i in count + 1:
		var at := lerpf(first + 0.22, last - 0.22, float(i) / count)
		piers.append(G.box_transform(Vector3(at, 1.22, 0), Vector3(0.45, 2.64, 0.84)))
	G.batch(parent, "MasonryPiers", unit_box, material, piers)


func _gate(parent: Node3D, label: String, center: float, span: float, notice_text := "") -> void:
	var boarded := not notice_text.is_empty()
	var gate := G.group(parent, label, Vector3(center, 0, 0))
	for side in [-1.0, 1.0]:
		var x: float = side * (span * 0.5 - 0.25)
		G.box(gate, "GranitePillar", Vector3(x, 1.46, 0), Vector3(0.70, 3.05, 0.82), granite, true)
		G.box(gate, "CarvedCap", Vector3(x, 3.03, 0), Vector3(0.91, 0.18, 1.0), coping)
	var width := span - 0.78
	var height := 2.35 if boarded else 2.70
	if boarded:
		G.box(gate, "BoardedWorksGate", Vector3(0, height * 0.5, 0), Vector3(width, height, 0.24), timber, true)
		var battens: Array[Transform3D] = []
		for i in ceili(width / 0.31):
			var x := -width * 0.5 + (float(i) + 0.5) * width / ceili(width / 0.31)
			battens.append(G.box_transform(Vector3(x, height * 0.5, 0), Vector3(0.035, height, 0.29)))
		G.batch(gate, "BoardJoints", unit_box, iron, battens)
		var notice := Label3D.new()
		notice.text = notice_text
		notice.font_size = 36
		notice.pixel_size = 0.0045
		notice.position = Vector3(0, 1.58, 0.16 if parent.name != "South" else -0.16)
		if parent.name == "South":
			notice.rotation.y = PI
		gate.add_child(notice)
		if notice_text != WORKS_NOTICE:
			for side in [-1.0, 1.0]:
				var rise := 0.8
				var run := width * 0.5 - 0.28
				var brace := G.box(gate, "DiagonalTimberBrace",
						Vector3(side * width * 0.25, 0.83, notice.position.z),
						Vector3(Vector2(run, rise).length(), 0.16, 0.11), timber)
				brace.rotation.z = side * atan2(rise, run)
	else:
		var bars: Array[Transform3D] = []
		var count := ceili(width / 0.19)
		for index in count + 1:
			var x := lerpf(-width * 0.5, width * 0.5, float(index) / count)
			var top := height + 0.21 * cos(PI * x / width)
			bars.append(G.box_transform(Vector3(x, top * 0.5, 0), Vector3(0.052, top, 0.085)))
		G.batch(gate, "WroughtIronBars", unit_box, iron, bars)
		G.collider(gate, "GateLeavesCollision", Vector3(0, height * 0.5, 0), Vector3(width, height, 0.13))
	var frame := timber if boarded else iron
	for y in [0.31, 1.18, height - 0.16]:
		G.box(gate, "GateCrosspiece", Vector3(0, y, 0), Vector3(width, 0.12, 0.30 if boarded else 0.14), frame)
	G.box(gate, "MeetingStile", Vector3(0, height * 0.5, 0), Vector3(0.16, height, 0.30), frame)


func _quay(parent: Node3D, label: String, first: float, last: float, z: float) -> void:
	var quay := G.group(parent, label, Vector3((first + last) * 0.5, 0, z))
	var span := last - first
	G.box(quay, "GraniteFacing", Vector3(0, -1.46, 0), Vector3(span, 3.08, 0.65), granite)
	G.box(quay, "ParapetBase", Vector3(0, 0.22, 0), Vector3(span, 0.50, 0.62), granite, true)
	for y in [0.68, 1.28]:
		G.box(quay, "IronRail", Vector3(0, y, 0), Vector3(span, 0.09, 0.11), iron)
	var posts: Array[Transform3D] = []
	var count := ceili(span / 1.85)
	for index in count + 1:
		var x := lerpf(-span * 0.5 + 0.04, span * 0.5 - 0.04, float(index) / count)
		posts.append(G.box_transform(Vector3(x, 0.87, 0), Vector3(0.10, 0.90, 0.14)))
	G.batch(quay, "IronUprights", unit_box, iron, posts)
	G.collider(quay, "IronRailCollision", Vector3(0, 0.88, 0), Vector3(span, 0.90, 0.14))


func _tile(parent: Node3D, label: String, first: float, last: float, front: float,
		back: float, height: float, material: Material) -> void:
	G.box(parent, label, Vector3((first + last) * 0.5, height - 0.10, (front + back) * 0.5),
			Vector3(last - first, 0.20, back - front), material, true)
