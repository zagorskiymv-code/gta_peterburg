@tool
extends RefCounted

const G = preload("res://scripts/world/district_geometry.gd")
const WATER := preload("res://materials/canal_water.gdshader")
const DEATH = preload("res://scripts/world/water_death_zone.gd")

enum Detail { NEAR, MIDDLE, FAR }

var unit := BoxMesh.new()
var gabled := PrismMesh.new()
var pavement := G.solid_material(Color("#8b8c81"))
var road := G.solid_material(Color("#646a68"))
var walk := G.solid_material(Color("#a39b89"))
var granite := G.solid_material(Color("#8a8d85"))
var trim := G.solid_material(Color("#baaf97"))
var windows := G.solid_material(Color("#454f51"))
var flue_brick := G.solid_material(Color("#825a4d"))
var roofs: Array[StandardMaterial3D] = []
var walls: Array[StandardMaterial3D] = []


func build(district: Node3D) -> void:
	var city := G.group(district, "BackgroundCity")
	var near := G.group(city, "Near")
	var middle := G.group(city, "Middle")
	var far := G.group(city, "Far")
	for tint in ["#b8a58a", "#8f9d83", "#af8377", "#bfa371", "#8b9d9f", "#aa947d"]:
		walls.append(G.solid_material(Color(tint)))
	for tint in ["#435653", "#4e535c", "#674d46"]:
		roofs.append(G.solid_material(Color(tint)))
	_base(city)
	_east(near, middle, far)
	_north(near, middle, far)
	_south(near, middle, far)
	_river(city, near, middle, far)
	_skyline(far)


func _base(city: Node3D) -> void:
	# The south mask leaves the canal, the island and their navigable channels uncovered.
	var dry_ground: Array[Vector4] = [Vector4(90, -290, 845, 149), Vector4(-92, -1080, 845, -290),
			Vector4(-92, 90, 5, 149), Vector4(62, 90, 90, 149),
			Vector4(-92, 149, 48, 268), Vector4(62, 149, 845, 268), Vector4(-92, 268, 845, 860)]
	city.set_meta(&"dry_ground", dry_ground)
	for rect in dry_ground:
		_surface(city, "CityGround", rect, pavement, -0.085)
	var sea := PlaneMesh.new()
	sea.size = Vector2(1210, 1940)
	var material := ShaderMaterial.new()
	material.shader = WATER
	var at := Vector3(-694.9, -2.85, -175)
	var water := G.mesh_part(city, "DistantNeva", at, sea, material)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Replace the old outer-water fall zone with one aligned to this one water plane.
	DEATH.add_at_surface(city, at, sea.size)
	var southern_cut := PlaneMesh.new()
	southern_cut.size = Vector2(14, 122)
	var canal := G.mesh_part(city, "DistantCanal", Vector3(55,-2.35,207), southern_cut, material)
	canal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	DEATH.add_at_surface(city, canal.position, southern_cut.size)


func _east(near: Node3D, middle: Node3D, far: Node3D) -> void:
	var east_blocks := [Vector2(84, 111), Vector2(31, 68), Vector2(-20, 16),
			Vector2(-68,-34), Vector2(-114,-83), Vector2(-167,-128),
			Vector2(-224,-182), Vector2(-279,-256), Vector2(-247,-239)]
	for band: Vector2 in east_blocks:
		_row(near, Vector2(98, band.y), Vector2(98, band.x), Detail.NEAR, int(band.y)+440)
		_row(middle, Vector2(130, band.y+4), Vector2(130, band.x), Detail.MIDDLE, int(band.y)+488)
		_row(middle, Vector2(165, band.y), Vector2(165, band.x-3), Detail.MIDDLE, int(band.y)+764)
	for cross: Vector2 in [Vector2(-33,-21),Vector2(65,72),Vector2(-126,-117),Vector2(-191,-181),Vector2(-255.4,-247.4)]:
		_surface(near, "CrossStreetContinuation", Vector4(90,cross.x,196,cross.y), road, -0.060)
	for x in [215.0, 274.0, 360.0, 475.0]:
		for z in [-340.0,-260.0,-180.0,-100.0,-20.0,60.0]:
			_row(far, Vector2(x,z+52), Vector2(x,z), Detail.FAR, int(x)+int(z)+632)


func _north(near: Node3D, middle: Node3D, far: Node3D) -> void:
	for band: Vector2 in [Vector2(-82,-42),Vector2(-35,4),Vector2(15,57),Vector2(65,106)]:
		_row(near, Vector2(band.y,-299), Vector2(band.x,-299), Detail.NEAR, int(band.y)+94)
		_row(middle, Vector2(band.y+4,-330), Vector2(band.x,-330), Detail.MIDDLE, int(band.y)+954)
	for line: Vector2 in [Vector2(-42,-35),Vector2(4,15),Vector2(57,65)]:
		_surface(near, "NorthernLaneContinuation", Vector4(line.x,-369,line.y,-290), road,-0.06)
	for z in [-375.0,-420.0,-495.0,-590.0]:
		for x in [-78.0,-10.0,58.0,126.0,194.0]:
			_row(far, Vector2(x+53,z),Vector2(x,z),Detail.FAR, int(x)-int(z))


func _south(near: Node3D, middle: Node3D, far: Node3D) -> void:
	for band: Vector2 in [Vector2(-88,-57),Vector2(-48,-8),Vector2(64,88)]:
		_row(near, Vector2(band.x,101),Vector2(band.y,101),Detail.NEAR, int(band.y)+91)
	for z in [153.0,189.0,225.0]:
		for band: Vector2 in [Vector2(-83,-55),Vector2(-48,-12),Vector2(4,43),Vector2(65,99)]:
			_row(middle,Vector2(band.x,z),Vector2(band.y,z),Detail.MIDDLE,int(z)+int(band.y))
	for z in [284.0,347.0,428.0,526.0]:
		for x in [-83.0,-19.0,45.0,109.0]:
			_row(far,Vector2(x,z),Vector2(x+50,z),Detail.FAR, int(z)+int(x))
	_surface(near,"SouthernAxialStreet",Vector4(-4,90,4,272),road,-0.06)
	_surface(near,"SouthWestLane",Vector4(-56,90,-49,198),road,-0.06)
	_surface(near,"OuterQuayContinuation",Vector4(68,90,74,149),road,-0.06)
	# Follow the water past the playable returns around New Holland.
	for bank: Vector3 in [Vector3(4.88,119.5,59), Vector3(62.12,119.5,59)]:
		G.box(near,"HollandDistantQuay",Vector3(bank.x,-1.46,bank.y),Vector3(0.26,2.82,bank.z),granite)
	G.box(near,"HollandFarQuay",Vector3(26.5,-1.46,149),Vector3(43,2.82,0.26),granite)
	for x in [47.85,62.15]:
		G.box(middle,"CanalGraniteEdge",Vector3(x,-1.39,207),Vector3(0.32,2.47,122),granite)


func _river(city: Node3D, near: Node3D, middle: Node3D, far: Node3D) -> void:
	# The tip of the opposite bank meets the unopened west landing of the Palace Bridge.
	var shore := PackedVector2Array([Vector2(-340,-1060),Vector2(-268,-470),Vector2(-261,-397),
		Vector2(-254,-336),Vector2(-246,-299),Vector2(-232,-273),Vector2(-213,-258),
		Vector2(-232,-241),Vector2(-244,-203),Vector2(-263,-160),Vector2(-278,-109),
		Vector2(-271,-45),Vector2(-257,35),Vector2(-243,118),Vector2(-238,284),Vector2(-315,850)])
	city.set_meta(&"west_shore", shore)
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wall_tops: Array[Transform3D] = []
	var wall_faces: Array[Transform3D] = []
	for i in shore.size()-1:
		var a := shore[i]
		var b := shore[i+1]
		for p: Vector2 in [Vector2(-1250,a.y),a,b,Vector2(-1250,a.y),b,Vector2(-1250,b.y)]:
			mesh.add_vertex(Vector3(p.x,-0.12,p.y))
		var direction := (b-a).normalized()
		var frame := _frame(direction)
		var center := (a+b)*0.5
		var span := a.distance_to(b)
		wall_tops.append(Transform3D(frame.scaled_local(Vector3(span+1.2,0.36,1.08)), Vector3(center.x,0.11,center.y)))
		wall_faces.append(Transform3D(frame.scaled_local(Vector3(span+0.5,2.77,0.82)), Vector3(center.x,-1.40,center.y)))
		if i < 2 or i > 11:
			continue
		var inland := Vector2(-direction.y,direction.x)
		# Both building lines sit on the inland side of the surveyed quay.
		var corner_setback := Vector2(-16,0) if i in [5,6] else Vector2.ZERO
		_row(near,a+direction*1.0+inland*9.5+corner_setback,
				b-direction*1.0+inland*9.5+corner_setback,Detail.NEAR,183+i*81)
		_row(middle,a+direction*1.0+inland*40,b-direction*1.0+inland*40,Detail.MIDDLE,957+i)
		_row(far,a+direction*2.0+inland*73,b-direction*2.0+inland*73,Detail.FAR,1889+i)
	mesh.generate_normals()
	var bank := G.mesh_part(city,"WestBankGround",Vector3.ZERO,mesh.commit(),pavement)
	bank.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_batch(city,"GraniteRiverWall",unit,granite,wall_faces,Detail.MIDDLE)
	_batch(city,"ContinuousQuayCoping",unit,walk,wall_tops,Detail.MIDDLE)


func _row(parent: Node3D, start: Vector2, end: Vector2, detail: Detail, seed_value: int) -> void:
	var distance := start.distance_to(end)
	if distance < 5:
		return
	var tangent := (end-start).normalized()
	var frame := _frame(tangent)
	var section := G.group(parent,"StreetFront",Vector3(start.x,0,start.y))
	section.basis = frame
	section.set_meta(&"frontage_length", distance)
	section.set_meta(&"frontage_depth", 18.0 if detail == Detail.FAR else 12.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var wall_groups: Array[Array] = []
	var roof_groups: Array[Array] = []
	for material in walls:
		wall_groups.append([])
	for material in roofs:
		roof_groups.append([])
	var borders: Array[Transform3D] = []
	var panes: Array[Transform3D] = []
	var flues: Array[Transform3D] = []
	var count := maxi(1, roundi(distance / (10.5 if detail != Detail.FAR else 15.0)))
	var offset := 0.0
	for lot in count:
		var equal := distance/count
		var width := equal + rng.randf_range(-1.7,1.7) if lot < count-1 else distance-offset
		width = clampf(width, minf(5.5,distance-offset), distance-offset-((count-lot-1)*5.0))
		var floors := rng.randi_range(3,5)
		var h := floors*2.62+0.20
		var depth := rng.randf_range(9.25,12.5) if detail != Detail.FAR else rng.randf_range(12.0,18.0)
		var x := offset+width*0.5
		var color_index := rng.randi_range(0,walls.size()-1)
		var roof_index := rng.randi_range(0,roofs.size()-1)
		var roof_rise := rng.randf_range(0.95,2.25)
		wall_groups[color_index].append(G.box_transform(Vector3(x,h*0.5,depth*0.5),Vector3(width-0.025,h,depth)))
		roof_groups[roof_index].append(Transform3D(Basis(Vector3.UP,PI*0.5).scaled_local(Vector3(depth+0.07,roof_rise,width+0.04)),
				Vector3(x,h+roof_rise*0.5,depth*0.5)))
		if detail != Detail.FAR:
			borders.append(G.box_transform(Vector3(x,h-0.08,-0.05),Vector3(width,0.19,0.21)))
			flues.append(G.box_transform(Vector3(x-width*0.23,h+roof_rise*0.82,depth*0.52),Vector3(0.53,1.37,0.48)))
			if lot % 3 == 0:
				flues.append(G.box_transform(Vector3(x+width*0.25,h+roof_rise*0.83,depth*0.49),Vector3(0.65,1.65,0.52)))
		if detail == Detail.NEAR:
			_windows(panes,borders,x,width,floors)
		elif detail == Detail.MIDDLE:
			# One relief band per upper storey keeps distant fenestration legible.
			for level in range(1,floors):
				borders.append(G.box_transform(Vector3(x,level*2.62,-0.037),Vector3(width-0.30,0.12,0.12)))
		offset += width
	for group in wall_groups.size():
		_batch(section,"Stucco",unit,walls[group],_transforms(wall_groups[group]),detail)
	for group in roof_groups.size():
		_batch(section,"PitchedRoof",gabled,roofs[group],_transforms(roof_groups[group]),detail)
	_batch(section,"StoneBands",unit,trim,borders,detail)
	_batch(section,"Glazing",unit,windows,panes,detail)
	_batch(section,"Chimneys",unit,flue_brick,flues,detail)


func _windows(panes: Array[Transform3D], edges: Array[Transform3D], x: float, width: float, floors: int) -> void:
	var bays := maxi(2, floori(width/1.9))
	for floor_index in floors:
		var y := 1.59+floor_index*2.62
		for i in bays:
			var bay_x := x+(i-(bays-1)*0.5)*(width/bays)
			edges.append(G.box_transform(Vector3(bay_x,y,-0.037),Vector3(0.99,1.31,0.08)))
			panes.append(G.box_transform(Vector3(bay_x,y,-0.085),Vector3(0.76,1.13,0.034)))
			edges.append(G.box_transform(Vector3(bay_x,y-0.63,-0.09),Vector3(1.02,0.1,0.14)))
	edges.append(G.box_transform(Vector3(x,0.26,-0.041),Vector3(width,0.47,0.11)))


func _skyline(far: Node3D) -> void:
	for site: Vector3 in [Vector3(251,0,-206),Vector3(331,0,111),Vector3(-46,0,-430),
			Vector3(-359,0,-340),Vector3(-319,0,-130),Vector3(81,0,343)]:
		var scale_factor := 0.83 + absf(fmod(site.z,37))/67.0
		var tower := G.group(far,"HistoricSkyline",site)
		tower.scale = Vector3.ONE*scale_factor
		var accent := Color("#9e8153") if site.x < 0 else Color("#607970")
		var dome_color := G.solid_material(accent)
		G.box(tower,"Belfry",Vector3.UP*8.5,Vector3(8.5,17,8.5),walls[3])
		G.box(tower,"Cornice",Vector3.UP*16.7,Vector3(9.1,0.71,9.1),trim)
		var top := CylinderMesh.new()
		top.radial_segments = 12
		if site.x < -300 or site.z < -400:
			top.height = 14
			top.top_radius = 0.09
			top.bottom_radius = 2.15
			G.mesh_part(tower,"Steeple",Vector3.UP*24,top,dome_color)
		else:
			top.height = 2.7
			top.top_radius = 3.52
			top.bottom_radius = 3.78
			G.mesh_part(tower,"Drum",Vector3.UP*18.4,top,trim)
			var dome := SphereMesh.new()
			dome.radius = 3.6
			dome.height = 3.3
			dome.radial_segments = 14
			dome.rings = 7
			dome.is_hemisphere = true
			G.mesh_part(tower,"Dome",Vector3.UP*19.75,dome,dome_color)
			G.box(tower,"Finial",Vector3.UP*23.42,Vector3(0.22,1.21,0.22),dome_color)


func _frame(tangent: Vector2) -> Basis:
	var direction := Vector3(tangent.x,0,tangent.y)
	return Basis(direction,Vector3.UP,direction.cross(Vector3.UP))


func _surface(parent: Node3D, label: String, bounds: Vector4, material: Material, height: float) -> void:
	var item := G.box(parent,label,Vector3((bounds.x+bounds.z)*0.5,height-0.08,(bounds.y+bounds.w)*0.5),
			Vector3(bounds.z-bounds.x,0.16,bounds.w-bounds.y),material)
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _transforms(items: Array) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	result.assign(items)
	return result


func _batch(parent: Node3D, title: String, shape: Mesh, material: Material,
		transforms: Array[Transform3D], detail: Detail) -> void:
	if transforms.is_empty():
		return
	G.batch(parent,title,shape,material,transforms)
	var instances := parent.get_child(parent.get_child_count()-1) as MultiMeshInstance3D
	if detail != Detail.NEAR or title == "Glazing" or parent.global_position.x < -150:
		instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
