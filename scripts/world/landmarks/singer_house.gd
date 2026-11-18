@tool
extends Node3D

const G = preload("res://scripts/world/district_geometry.gd")
var stone := G.solid_material(Color("#beb6a7"))
var dressed := G.solid_material(Color("#d2c5ab"))
var glazing := G.solid_material(Color("#526b70"))
var roof := G.solid_material(Color("#515a55"))
var bronze := G.solid_material(Color("#617064"))
var unit := BoxMesh.new()


func _ready() -> void:
	_masonry("SingerMasonry", 0.0, 19.45, stone, true)
	_masonry("RedGreyGranite", 0.0, 7.42, G.solid_material(Color("#876965")), false, 1.008)
	_masonry("SculptedCornice", 19.12, 19.58, dressed, false, 1.04)
	var mansard := PrismMesh.new()
	mansard.size = Vector3(12.8, 2.25, 16.9)
	G.mesh_part(self, "DarkMansard", Vector3(0, 20.53, 0), mansard, roof)
	var frames: Array[Transform3D] = []
	var panes: Array[Transform3D] = []
	var ironwork: Array[Transform3D] = []
	var courses: Array[Transform3D] = []
	var granite := G.solid_material(Color("#947973"))
	var levels := [2.10, 5.76, 9.06, 11.86, 14.66, 17.40]
	var heights := [3.49, 3.11, 2.26, 2.32, 2.32, 2.03]
	for side in 4:
		var frame := Basis(Vector3.UP, side * PI / 2)
		var depth := 8.70 if side % 2 == 0 else 6.60
		var frontage := 13.2 if side % 2 == 0 else 17.4
		var bays := 5 if side % 2 == 0 else 6
		for y in [0.25, 3.97, 7.46, 10.43, 16.05, 18.67, 19.28]:
			var band_width := frontage - 0.95 if side in [0, 3] else frontage
			var offset := 0.47 if side == 0 else (-0.47 if side == 3 else 0.0)
			courses.append(_part(frame, Vector3(offset, y, depth+0.11), Vector3(band_width, 0.16, 0.29)))
		for bay in bays:
			var x := lerpf(-frontage*0.40, frontage*0.40, bay / float(bays-1))
			if (side == 0 and x < -4.55) or (side == 3 and x > 5.78):
				continue
			for floor_index in levels.size():
				var y: float = levels[floor_index]
				var height: float = heights[floor_index]
				var w := 1.77 if side % 2 == 0 else 1.93
				var entry := side == 3 and floor_index == 0 and bay == 2
				frames.append(_part(frame, Vector3(x, y, depth+0.076), Vector3(w+0.29, height+0.26, 0.22)))
				panes.append(_part(frame, Vector3(x, y, depth+0.221), Vector3(w, height, 0.15)))
				ironwork.append(_part(frame, Vector3(x, y, depth+0.306), Vector3(0.065, height, 0.076)))
				ironwork.append(_part(frame, Vector3(x, y+height*0.22, depth+0.31), Vector3(w, 0.062, 0.065)))
				if floor_index == 0 or floor_index == 2:
					_architrave(courses, frame, Vector3(x, y + height*0.40, depth+0.265), w*0.58, 0.30)
				if floor_index == 3 and side in [0, 3] and bay % 2 == 0:
					_balcony(courses, ironwork, frame, Vector3(x, y-height*0.45, depth+0.19), w+0.18)
				if entry:
					ironwork.append(_part(frame, Vector3(x, y-0.16, depth+0.31), Vector3(w*0.91, 2.81, 0.11)))
					_plaque(frame, Vector3(x, 4.06, depth+0.32))
		for x in [-frontage*0.46, 0.0, frontage*0.46]:
			if (side == 0 and x < -4.55) or (side == 3 and x > 5.78):
				continue
			G.box(self, "RusticatedPilaster", frame * Vector3(x, 3.73, depth+0.125),
					Vector3(0.39, 7.32, 0.29), granite).rotation.y = side * PI * 0.5
	G.batch(self, "CarvedStoneAndCornices", unit, dressed, courses)
	G.batch(self, "CarvedWindowFrames", unit, dressed, frames)
	G.batch(self, "TallShopWindows", unit, glazing, panes)
	G.batch(self, "ArtNouveauIronwork", unit, bronze, ironwork)
	var corner := G.group(self, "ChamferedCorner", Vector3(-5.61, 0, 7.72))
	corner.rotation_degrees.y = -45
	for i in levels.size():
		var at := Vector3(0, levels[i], 0.02)
		G.box(corner, "CarvedCornerBay", at, Vector3(1.68, heights[i]+0.31, 0.25), dressed)
		G.box(corner, "CurvedCornerGlazing", at + Vector3.BACK*0.145, Vector3(1.35, heights[i], 0.115), glazing)
		G.box(corner, "CornerMullion", at + Vector3.BACK*0.22, Vector3(0.078, heights[i], 0.075), bronze)
		G.box(corner, "Sill", at + Vector3(-0.0, -heights[i]*0.49, 0.215), Vector3(1.7, 0.15, 0.24), dressed)
	for side in [-1.0, 1.0]:
		_valkyrie(corner, Vector3(side*0.81, 7.25, 0.56), side, 1.0)
	_tower(G.group(self, "CornerTower", Vector3(-4.83, 19.42, 6.44)))


func _plaque(frame: Basis, at: Vector3) -> void:
	var label := Label3D.new()
	label.text = "ЗИНГЕРЪ"
	label.font_size = 38
	label.pixel_size = 0.005
	label.outline_size = 1
	label.modulate = Color("#f3deb1")
	label.transform = Transform3D(frame, frame * at)
	add_child(label)


func _architrave(parts: Array[Transform3D], frame: Basis, base: Vector3, radius: float, rise: float) -> void:
	for i in 9:
		var angle := PI * i / 8.0
		var v := base + Vector3(cos(angle)*radius, sin(angle)*rise, 0)
		var tangent := atan2(cos(angle)*rise, -sin(angle)*radius)
		parts.append(Transform3D((frame * Basis(Vector3.BACK, tangent)).scaled_local(
				Vector3(0.36, 0.15, 0.14)), frame*v))


func _balcony(stone_parts: Array[Transform3D], iron_parts: Array[Transform3D],
		frame: Basis, at: Vector3, span: float) -> void:
	stone_parts.append(_part(frame, at + Vector3(0,-0.10,0.23), Vector3(span,0.16,0.62)))
	for i in 9:
		var x := lerpf(-span/2.0, span/2.0, i/8.0)
		iron_parts.append(_part(frame, at + Vector3(x,0.33,0.49), Vector3(0.047,0.66,0.064)))
		iron_parts.append(Transform3D((frame * Basis(Vector3.BACK, 0.42 if i % 2 == 0 else -0.42)).scaled_local(
				Vector3(0.026,0.31,0.040)), frame*(at + Vector3(x,0.30,0.5))))
	for y in [0.10,0.65]:
		iron_parts.append(_part(frame, at + Vector3(0,y,0.49), Vector3(span,0.061,0.077)))


func _masonry(label: String, bottom: float, top: float, material: Material, solid := false, expansion := 1.0) -> void:
	var outline := [Vector2(-6.6, -8.7), Vector2(6.6, -8.7), Vector2(6.6, 8.7),
		Vector2(-4.65, 8.7), Vector2(-6.6, 6.75)]
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	mesh.set_smooth_group(-1)
	for i in outline.size():
		var a: Vector2 = outline[i] * expansion
		var b: Vector2 = outline[(i + 1) % outline.size()] * expansion
		var p := Vector3(a.x, bottom, a.y)
		var q := Vector3(b.x, bottom, b.y)
		var r := Vector3(b.x, top, b.y)
		var t := Vector3(a.x, top, a.y)
		for vertex: Vector3 in [p, q, r, p, r, t, Vector3.UP * top, t, r]:
			mesh.add_vertex(vertex)
	mesh.generate_normals()
	var shape_mesh := mesh.commit()
	G.mesh_part(self, label, Vector3.ZERO, shape_mesh, material)
	if solid:
		var body := StaticBody3D.new()
		body.name = "SingerMasonryCollision"
		body.collision_mask = 0
		var collider := CollisionShape3D.new()
		collider.shape = shape_mesh.create_convex_shape()
		body.add_child(collider)
		add_child(body)


func _tower(tower: Node3D) -> void:
	var drum := CylinderMesh.new()
	drum.radial_segments = 12
	drum.height = 1.06
	drum.top_radius = 2.13
	drum.bottom_radius = 2.31
	G.mesh_part(tower, "StoneTowerPlinth", Vector3.UP*0.47, drum, dressed)
	var blue := glazing.duplicate() as StandardMaterial3D
	blue.albedo_color = Color("#527a74")
	blue.roughness = 0.27
	blue.metallic = 0.22
	var dome := SphereMesh.new()
	dome.radius = 2.03
	dome.height = 1.8
	dome.radial_segments = 24
	dome.rings = 12
	dome.is_hemisphere = true
	G.mesh_part(tower, "GlazedCupola", Vector3.UP*4.06, dome, blue)
	var rails: Array[Transform3D] = []
	for meridian in 12:
		var angle := TAU * meridian / 12.0
		var horizontal := Vector3(cos(angle),0,sin(angle))
		var tangent := Vector3(-sin(angle),0,cos(angle))
		var pane_frame := Basis(Vector3.UP, atan2(horizontal.x, horizontal.z))
		G.mesh_part(tower, "TallTurretGlass", horizontal*1.974+Vector3.UP*2.52,
				unit, blue).transform.basis = pane_frame.scaled_local(Vector3(1.04,3.05,0.065))
		for side in [-1.0,1.0]:
			rails.append(G.box_transform(horizontal*1.99 + tangent*side*0.52 + Vector3.UP*2.53, Vector3(0.105,3.19,0.105)))
		for y in [1.05,2.3,4.02]:
			rails.append(Transform3D(pane_frame.scaled_local(Vector3(1.09,0.095,0.078)), horizontal*2.01 + Vector3.UP*y))
		for i in 8:
			var a := PI*i/16.0
			var b := PI*(i+1)/16.0
			var start := horizontal*2.07*cos(a)+Vector3.UP*(4.06+1.80*sin(a))
			var end := horizontal*2.07*cos(b)+Vector3.UP*(4.06+1.80*sin(b))
			var span := end-start
			rails.append(Transform3D(Basis.looking_at(span, horizontal).scaled_local(Vector3(0.09,0.09,span.length()+0.016)), (start+end)*0.5))
	G.batch(tower, "TurretAndDomeIronwork", unit, bronze, rails)
	var globe_center := Vector3.UP*7.33
	var globe := SphereMesh.new()
	globe.radius = 1.40
	globe.height = 2.80
	globe.radial_segments = 32
	globe.rings = 18
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.49,0.77,0.67,0.28)
	glass.roughness = 0.17
	glass.emission_enabled = true
	glass.emission = Color("#68b195")
	glass.emission_energy_multiplier = 0.29
	G.mesh_part(tower, "TransparentGlassGlobe", globe_center, globe, glass)
	var lamp := StandardMaterial3D.new()
	lamp.albedo_color = Color("#e7cf93")
	lamp.emission_enabled = true
	lamp.emission = Color("#d9bd6c")
	lamp.emission_energy_multiplier = 0.56
	G.mesh_part(tower, "GlowInsideGlobe", globe_center, globe, lamp).scale = Vector3.ONE*0.33
	var band := TorusMesh.new()
	band.inner_radius = 1.385
	band.outer_radius = 1.43
	band.rings = 36
	band.ring_segments = 6
	for rotation in [Vector3.ZERO,Vector3(90,0,0),Vector3(90,60,0),Vector3(90,120,0)]:
		G.mesh_part(tower, "GlobeArmature", globe_center, band, bronze).rotation_degrees = rotation
	for side in [-1.0,1.0]:
		_valkyrie(tower, Vector3(side*0.81,5.41,0.30), side, 0.70)


func _valkyrie(parent: Node3D, at: Vector3, side: float, size: float) -> void:
	var statue := G.group(parent, "BronzeValkyrie", at)
	statue.scale = Vector3.ONE*size
	var shape := SphereMesh.new()
	shape.radial_segments = 11
	shape.rings = 6
	G.mesh_part(statue,"FlowingBronze",Vector3(0,0.60,0.12),shape,bronze).scale = Vector3(0.48,1.27,0.37)
	G.mesh_part(statue,"FigureHead",Vector3(0,1.31,0.17),shape,bronze).scale = Vector3(0.26,0.31,0.24)
	var wing := G.mesh_part(statue,"RaisedWing",Vector3(side*0.30,1.00,0.11),shape,bronze)
	wing.scale = Vector3(0.57,1.0,0.14)
	wing.rotation_degrees.z = -side*32
	G.mesh_part(statue,"ExtendedArm",Vector3(-side*0.22,1.31,0.25),shape,bronze).scale = Vector3(0.20,0.59,0.21)
	G.box(statue,"ShipProwCorbel",Vector3(0,0.03,0.14),Vector3(0.47,0.29,0.52),dressed)


func _part(frame: Basis, at: Vector3, size: Vector3) -> Transform3D:
	return Transform3D(frame.scaled_local(size), frame * at)
