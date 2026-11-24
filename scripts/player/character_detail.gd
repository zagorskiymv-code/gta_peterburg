extends RefCounted

const Materials = preload("res://scripts/player/character_materials.gd")

static var _oval: SphereMesh
static var _meshes: Dictionary = {}
static var _faces: Dictionary = {}


static func apply(visual: Node3D) -> void:
	var upper: Node3D = visual.get_node("Body/UpperBody")
	var head: Node3D = upper.get_node("Head")
	var player_skin := Color("#ad785e")
	var hair := Color("#413026")
	var leather := Materials.get_material(Color("#32271f"), Materials.Finish.LEATHER)
	var felt := Materials.get_material(Color("#292729"))
	var wool: Dictionary = {}
	for part: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
		var old := part.material_override as StandardMaterial3D
		if old == null:
			continue
		if not wool.has(old):
			var tint := old.albedo_color
			var finish := Materials.Finish.WOOL
			match old.resource_name:
				"Wool":
					tint = Color("#2d3840")
				"Lapel":
					tint = Color("#424a50")
				"Waistcoat":
					tint = Color("#664d36")
				"Skin":
					tint = player_skin
					finish = Materials.Finish.SKIN
				"Hair":
					tint = hair
					finish = Materials.Finish.HAIR
				"Leather":
					tint = Color("#32271f")
					finish = Materials.Finish.LEATHER
				"Brass":
					tint = Color("#ac8356")
					finish = Materials.Finish.METAL
			wool[old] = Materials.get_material(tint, finish)
		part.material_override = wool[old]

	# The node names remain available to the animation, wardrobe and reins.
	for name in ["Jaw", "Nose", "LeftEye", "RightEye"]:
		head.get_node(name).hide()
	var neck: MeshInstance3D = head.get_node("Neck")
	neck.scale = Vector3(.098, .143, .085)
	for name in ["BowlerCrown", "BowlerBrim"]:
		head.get_node(name).material_override = felt
	var crown: MeshInstance3D = head.get_node("BowlerCrown")
	crown.mesh = _cached_profile("hat", [
		Vector4(-.50, .46, .47, 0), Vector4(-.38, .50, .50, 0),
		Vector4(-.04, .48, .48, .008), Vector4(.29, .36, .38, .02),
		Vector4(.47, .17, .18, .026), Vector4(.50, .012, .012, .028)])
	head.get_node("BowlerCrown").position.y = .298
	head.get_node("BowlerBrim").scale.y = .014
	head.get_node("BowlerBand").scale.y = .022

	var knot: MeshInstance3D = upper.get_node("Cravat")
	knot.mesh = _cached_batch("tied cravat", [
		[Vector3(0,.11,-.07), Vector3(.49,.48,.59), Vector3(0,0,-.14)],
		[Vector3(-.21,-.06,0), Vector3(.47,.43,.47), Vector3(0,.18,.31)],
		[Vector3(.21,-.10,.03), Vector3(.48,.38,.46), Vector3(0,-.19,-.23)]])
	knot.position.z = -.164
	knot.scale = Vector3(.075,.058,.027)
	var torso: MeshInstance3D = upper.get_node("CoatTorso")
	torso.mesh = _cached_profile("coat torso", [
		Vector4(-.50, .44, .46, .007), Vector4(-.34, .435, .43, .014),
		Vector4(-.22, .47, .445, .015), Vector4(.03, .46, .48, -.005),
		Vector4(.28, .50, .49, -.014), Vector4(.42, .48, .46, -.006),
		Vector4(.5, .39, .36, .02)])
	var hem: MeshInstance3D = upper.get_node("CoatHem")
	if not _meshes.has("split coat skirts"):
		_meshes["split coat skirts"] = _coat_tails()
	hem.mesh = _meshes["split coat skirts"]
	hem.position.y = -.047
	hem.scale = Vector3(.459, .261, .31)
	for side: String in ["Left", "Right"]:
		var mirror := -1.0 if side == "Left" else 1.0
		var lapel: MeshInstance3D = upper.get_node(side + "Lapel")
		var key := "left lapel" if mirror < 0.0 else "right lapel"
		if not _meshes.has(key):
			_meshes[key] = _lapel_panel(mirror)
		lapel.mesh = _meshes[key]
		lapel.position = Vector3.ZERO
		lapel.rotation = Vector3.ZERO
		lapel.scale = Vector3.ONE
		var collar: MeshInstance3D = upper.get_node(side + "Collar")
		collar.scale = Vector3(.062, .077, .025)
		collar.mesh = _cached_profile("collars", [
			Vector4(-.5,.16,.16,0), Vector4(-.25,.47,.44,0),
			Vector4(.16,.5,.49,.01), Vector4(.5,.25,.49,.08)])
		var arm: Node3D = upper.get_node(side + "ArmPivot")
		var sleeve: MeshInstance3D = arm.get_node("UpperSleeve")
		sleeve.mesh = _cached_profile("upper sleeve", [
			Vector4(-.5,.37,.38,0),Vector4(-.42,.42,.44,.02),Vector4(-.30,.38,.4,.008),
			Vector4(-.02,.46,.44,0),Vector4(.29,.49,.47,0),Vector4(.40,.42,.43,.018),Vector4(.50,.245,.28,.053)])
		var elbow: Node3D = arm.get_node("Elbow")
		var forearm: MeshInstance3D = elbow.get_node("ForeSleeve")
		forearm.mesh = _cached_profile("fore sleeve", [
			Vector4(-.5,.34,.35,0),Vector4(-.37,.39,.41,0),Vector4(-.20,.414,.415,0),
			Vector4(.14,.44,.43,-.021),Vector4(.32,.47,.46,.016),Vector4(.43,.45,.45,.027),Vector4(.50,.30,.34,.038)])
		var cuff: MeshInstance3D = elbow.get_node("Cuff")
		cuff.mesh = _cached_profile("cuffs", [
			Vector4(-.5,.47,.47,0),Vector4(-.39,.50,.5,0),Vector4(.39,.50,.5,0),Vector4(.50,.45,.45,0)])
		cuff.scale = Vector3(.106,.041,.109)
		# The upper sleeve itself closes the shoulder. The overlapping sleeve
		# ends cover the elbow through its existing bend range.
		arm.get_node("Shoulder").hide()
		sleeve.position.y = -.103
		sleeve.scale.y = .321
		forearm.position.y = -.103
		forearm.scale.y = .258
		_hands(elbow, mirror, player_skin)

		var knee: Node3D = visual.get_node("Body/" + side + "LegPivot/Knee")
		var trouser: MeshInstance3D = knee.get_node("TrouserLeg")
		trouser.mesh = _cached_profile("trousers", [
			Vector4(-.5,.39,.39,0),Vector4(-.33,.43,.39,.008),Vector4(.12,.45,.46,.018),
			Vector4(.31,.45,.45,-.055),Vector4(.39,.49,.49,-.07),Vector4(.50,.47,.46,.025)])
		_shoe(knee.get_node("Ankle"), leather)

	configure_face(head, 0, player_skin, hair)


static func configure_face(head: Node3D, character: int, skin: Color, hair_color: Color) -> void:
	var key := "%d/%s/%s" % [character, skin.to_html(), hair_color.to_html()]
	if not _faces.has(key):
		_faces[key] = _make_face(character, skin, hair_color)
	var face: Dictionary = _faces[key]
	var skin_material := Materials.get_material(skin, Materials.Finish.SKIN)
	var hair_material := Materials.get_material(hair_color, Materials.Finish.HAIR)
	for name in ["Skull", "Hair", "LeftEar", "RightEar"]:
		var part: MeshInstance3D = head.get_node(name)
		part.mesh = face[name]
		part.position = Vector3.ZERO
		part.scale = Vector3.ONE
		part.material_override = hair_material if name == "Hair" else skin_material
	head.get_node("Neck").material_override = skin_material
	head.get_node("Moustache").material_override = hair_material
	var moustache: MeshInstance3D = head.get_node("Moustache")
	moustache.mesh = _cached_batch("moustache", [
		[Vector3(-.20, 0, -.02), Vector3(.65,.77,.63), Vector3(0,0,-.19)],
		[Vector3(.20, 0, -.02), Vector3(.65,.77,.63), Vector3(0,0,.19)]])
	moustache.position = Vector3(0, .120, -.1065)
	moustache.scale = Vector3(.061,.009,.013)
	var near := head.get_node_or_null("PortraitDetails") as MeshInstance3D
	if near == null:
		near = _part(head, "PortraitDetails", face["Details"], null)
		near.visibility_range_end = 15.0
		near.visibility_range_end_margin = 1.25
	else:
		near.mesh = face["Details"]
	near.set_meta(&"open_eyes", face["Details"])
	near.set_meta(&"closed_eyes", face["Blink"])


static func _make_face(character: int, skin: Color, hair_color: Color) -> Dictionary:
	var width: float = [1.0, 1.08, .93, 1.02, .96, 1.01][character]
	var chin: float = [1.0, 1.20, .93, 1.13, .84, 1.05][character]
	var head_mesh := _profile([
		Vector4(.066,.033 * chin,.041,-.030), Vector4(.076,.050 * chin,.054,-.030),
		Vector4(.087,.060 * chin,.064,-.026), Vector4(.100,.065 * chin,.074,-.021),
		Vector4(.110,.067 * chin,.080,-.016), Vector4(.120,.068 * chin,.083,-.014),
		Vector4(.132,.072 * width,.086,-.012), Vector4(.139,.076 * width,.088,-.009),
		Vector4(.148,.080 * width,.090,-.008), Vector4(.158,.083 * width,.090,-.006),
		Vector4(.169,.081 * width,.089,-.004), Vector4(.176,.079 * width,.089,-.003),
		Vector4(.184,.079 * width,.091,-.005), Vector4(.195,.079 * width,.092,-.005),
		Vector4(.212,.079 * width,.093,0), Vector4(.234,.068 * width,.085,.004),
		Vector4(.254,.044 * width,.053,.007), Vector4(.267,.007,.012,.010)], 36, true)
	var locks := [
		[Vector3(0,.209,.035),Vector3(.164 * width,.122,.144),Vector3(-.25,0,0)],
		[Vector3(-.037,.234,-.036),Vector3(.091,.043,.108),Vector3(.12,-.36,.17)],
		[Vector3(.024,.237,-.031),Vector3(.083,.041,.118),Vector3(.23,.30,-.17)],
		[Vector3(-.056,.205,.028),Vector3(.046,.066,.105),Vector3(-.24,-.15,-.12)],
		[Vector3(.058,.207,.026),Vector3(.046,.064,.106),Vector3(-.16,.19,.22)],
	]
	if character == 4:
		locks.append([Vector3(0,.171,.103),Vector3(.106,.091,.079),Vector3.ZERO])
	elif character == 5:
		locks = locks.slice(0, 3)
		locks[0] = [Vector3(0,.196,.047),Vector3(.159,.085,.132),Vector3.ZERO]
	var temples: Array = []
	var whites: Array = []
	var irises: Array = []
	var pupils: Array = []
	var lids: Array[Vector3] = []
	var closed_lids: Array = []
	var markings: Array = [
		[Vector3(.001,.109,-.104),Vector3(.041,.0023,.004),Vector3(0,0,-.036)],
	]
	var lips: Array = [
		[Vector3(.001,.105,-.1015),Vector3(.041,.005,.0058),Vector3.ZERO],
	]
	for side: float in [-1.0, 1.0]:
		var x := side * .038
		var eye_y := (.175 if character == 5 else .177) + side * .0008
		var eye_z := -.0756 + (1.0 - width) * .022
		var angle := Vector3(0, -side * .24, side * .04)
		whites.append([Vector3(x,eye_y,eye_z),Vector3(.026,.012,.018),angle])
		irises.append([Vector3(x-.0008,eye_y,eye_z-.0085),Vector3(.010,.010,.004),Vector3.ZERO])
		pupils.append([Vector3(x-.0008,eye_y+.0002,eye_z-.0103),Vector3(.0054,.0058,.0022),Vector3.ZERO])
		lids.append(Vector3(x,eye_y,eye_z))
		closed_lids.append([Vector3(x,eye_y,eye_z-.0058), Vector3(.027,.010,.0043), angle])
		temples.append([Vector3(x,.192+side*.001,-.087),Vector3(.034,.0045,.009),
				Vector3(0,-side*.24,side*.15)])
		markings.append([Vector3(side*.008,.137,-.1115),Vector3(.006,.0026,.0045),Vector3(0,0,side*.20)])
		lips.append([Vector3(side*.080*width,.152,.001),Vector3(.010,.023,.014),Vector3(0,0,-side*.14)])
	var details := ArrayMesh.new()
	var blink := ArrayMesh.new()
	var dark := Materials.get_material(Color("#392b25"))
	var lid := Materials.get_material(skin.darkened(.07), Materials.Finish.SKIN)
	var lip := Materials.get_material(skin.darkened(.13).lerp(Color("#a75854"), .28), Materials.Finish.SKIN)
	var brows := Materials.get_material(hair_color, Materials.Finish.HAIR)
	_append_batch(details, whites, Materials.get_material(Color("#bcb19f")))
	_append_batch(details, irises, Materials.get_material(Color("#596365") if character % 2 == 0 else Color("#645344")))
	_append_batch(details, pupils + markings, dark)
	_append_lids(details, lids, lid)
	_append_batch(blink, markings, dark)
	_append_batch(blink, closed_lids, lid)
	for mesh in [details, blink]:
		_append_batch(mesh, lips, lip)
		_append_batch(mesh, temples, brows)
	var ears: Dictionary = {}
	for side in [-1.0, 1.0]:
		ears["LeftEar" if side < 0.0 else "RightEar"] = _batch([
			[Vector3(side*.078*width,.158,.004),Vector3(.022,.053,.031),Vector3(.14,0,-side*.16)],
			[Vector3(side*.078*width,.142,-.001),Vector3(.014,.018,.020),Vector3.ZERO]])
	return {"Skull": head_mesh, "Hair": _batch(locks), "LeftEar": ears.LeftEar,
		"RightEar": ears.RightEar, "Details": details, "Blink": blink}


static func _append_lids(mesh: ArrayMesh, eyes: Array[Vector3], material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	for center in eyes:
		for edge: float in [-1.0, 1.0]:
			for step in 8:
				var u := float(step) / 4.0 - 1.0
				var v := float(step + 1) / 4.0 - 1.0
				var a := _lid_point(center, u, edge, false)
				var b := _lid_point(center, v, edge, false)
				var c := _lid_point(center, v, edge, true)
				var d := _lid_point(center, u, edge, true)
				var triangle := [a,b,c,a,c,d] if edge > 0.0 else [a,c,b,a,d,c]
				for point: Vector3 in triangle:
					surface.add_vertex(point)
	surface.generate_normals()
	surface.commit(mesh)


static func _lid_point(center: Vector3, u: float, edge: float, outer: bool) -> Vector3:
	var arc := sqrt(maxf(1.0 - u*u, 0.0))
	var x := u * .0138
	var y := arc * (.0050 if edge > 0.0 else .0039)
	var z := -.0068 + absf(u) * .0027 + signf(center.x) * x*.23
	if outer:
		y += .0021 + arc*.0011
		z += .0021
	return center + Vector3(x, y*edge, z)


static func _hands(elbow: Node3D, side: float, skin: Color) -> void:
	var hand: MeshInstance3D = elbow.get_node("Hand")
	var fingers: Array = [
		[Vector3(0,.04,0),Vector3(.90,.75,.75),Vector3.ZERO],
		[Vector3(0,.38,.015),Vector3(.65,.38,.63),Vector3.ZERO],
	]
	for index in 4:
		var x := (index - 1.5) * .211
		var length: float = [.39,.48,.44,.34][index]
		fingers.append([Vector3(x,-.292,-.089),Vector3(.272,length,.44),Vector3(.13,0,side*(index-1.5)*.045)])
	hand.mesh = _cached_batch("left hand" if side < 0.0 else "right hand", fingers)
	hand.scale = Vector3(.065,.097,.058)
	var thumb: MeshInstance3D = elbow.get_node("Thumb")
	thumb.mesh = _cached_batch("thumb", [
		[Vector3(0,.17,.02),Vector3(.82,.84,.91),Vector3(-.16,0,0)],
		[Vector3(0,-.23,-.11),Vector3(.65,.65,.68),Vector3(.21,0,0)]])
	thumb.rotation.z = side * .29
	thumb.scale = Vector3(.023,.048,.025)
	for part: MeshInstance3D in [hand, thumb]:
		part.material_override = Materials.get_material(skin, Materials.Finish.SKIN)


static func _shoe(ankle: Node3D, leather: Material) -> void:
	var upper: MeshInstance3D = ankle.get_node("BootUpper")
	upper.mesh = _cached_profile("boot upper", [
		Vector4(-.084,.064,.116,-.060),Vector4(-.074,.068,.119,-.059),
		Vector4(-.057,.063,.117,-.060),Vector4(-.034,.057,.103,-.050),
		Vector4(-.015,.054,.077,-.035),Vector4(.015,.053,.059,-.010),
		Vector4(.048,.048,.052,.001)])
	upper.position = Vector3.ZERO
	upper.scale = Vector3.ONE
	upper.material_override = leather
	ankle.get_node("Toe").hide()
	var sole: MeshInstance3D = ankle.get_node("Sole")
	sole.mesh = _cached_profile("sole", [
		Vector4(-.105,.058,.108,-.059),Vector4(-.101,.065,.121,-.057),
		Vector4(-.088,.069,.122,-.058),Vector4(-.081,.065,.119,-.058)])
	sole.position = Vector3.ZERO
	sole.scale = Vector3.ONE
	sole.material_override = Materials.get_material(Color("#261e19"), Materials.Finish.LEATHER)
	var vamp := _part(ankle, "VampCreases", _cached_batch("boot creases", [
		[Vector3(0,-.028,-.105),Vector3(.084,.009,.019),Vector3(-.34,0,.05)],
		[Vector3(0,-.036,-.123),Vector3(.088,.007,.014),Vector3(-.34,0,-.04)]]),
		Materials.get_material(Color("#423328"), Materials.Finish.LEATHER))
	vamp.visibility_range_end = 12.0


static func _part(parent: Node3D, name: String, mesh: Mesh, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = name
	part.mesh = mesh
	part.material_override = material
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	return part


static func _sphere() -> SphereMesh:
	if _oval == null:
		_oval = SphereMesh.new()
		_oval.radius = .5
		_oval.height = 1.0
		_oval.radial_segments = 10
		_oval.rings = 5
	return _oval


static func _cached_batch(key: String, shapes: Array) -> ArrayMesh:
	if not _meshes.has(key):
		_meshes[key] = _batch(shapes)
	return _meshes[key]


static func _batch(shapes: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	_append_batch(mesh, shapes, null)
	return mesh


static func _append_batch(mesh: ArrayMesh, shapes: Array, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	for shape: Array in shapes:
		var basis := Basis.from_euler(shape[2]).scaled_local(shape[1])
		surface.append_from(_sphere(), 0, Transform3D(basis, shape[0]))
	surface.commit(mesh)


static func _coat_tails() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := [
		Vector4(-.50,.50,.57,.015), Vector4(-.456,.518,.57,.015),
		Vector4(-.30,.499,.546,.012), Vector4(.03,.472,.49,.003),
		Vector4(.27,.439,.45,-.01), Vector4(.50,.42,.425,-.017),
	]
	for side in 2:
		# Each side is a separate panel, with an open front and a back vent.
		var start := -.93 + PI * side
		var sweep := 2.29
		for level in range(rings.size() - 1):
			for j in 10:
				var a := _tail_vertex(rings[level], start+sweep*j/10.0)
				var b := _tail_vertex(rings[level], start+sweep*(j+1)/10.0)
				var c := _tail_vertex(rings[level+1], start+sweep*(j+1)/10.0)
				var d := _tail_vertex(rings[level+1], start+sweep*j/10.0)
				for point: Vector3 in [a,b,c,a,c,d]:
					surface.add_vertex(point)
	# Cloth panels are small enough to keep a second winding for the visible lining.
	var outer := surface.commit_to_arrays()
	for n in range(0, outer[Mesh.ARRAY_VERTEX].size(), 3):
		for j in [0, 2, 1]:
			var point: Vector3 = outer[Mesh.ARRAY_VERTEX][n+j]
			surface.add_vertex(Vector3(point.x*.959, point.y, point.z*.959))
	surface.generate_normals()
	return surface.commit()


static func _tail_vertex(ring: Vector4, angle: float) -> Vector3:
	return Vector3(cos(angle)*ring.y, ring.x, sin(angle)*ring.z+ring.w)


static func _cached_profile(key: String, levels: Array) -> ArrayMesh:
	if not _meshes.has(key):
		_meshes[key] = _profile(levels, 16)
	return _meshes[key]


static func _profile(levels: Array, sides: int, sculpt := false) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for level in range(levels.size() - 1):
		for side in sides:
			var a := _ring(levels[level], side, sides, sculpt)
			var b := _ring(levels[level], side+1, sides, sculpt)
			var c := _ring(levels[level+1], side+1, sides, sculpt)
			var d := _ring(levels[level+1], side, sides, sculpt)
			for point: Vector3 in [a,b,c,a,c,d]:
				surface.add_vertex(point)
	surface.set_smooth_group(-1)
	var first: Vector4 = levels.front()
	var last: Vector4 = levels.back()
	for side in sides:
		for point: Vector3 in [Vector3(0,first.x,first.w),_ring(first,side+1,sides,sculpt),_ring(first,side,sides,sculpt),
				Vector3(0,last.x,last.w),_ring(last,side,sides,sculpt),_ring(last,side+1,sides,sculpt)]:
			surface.add_vertex(point)
	surface.generate_normals()
	surface.index()
	return surface.commit()


static func _ring(level: Vector4, side: int, sides: int, sculpt: bool) -> Vector3:
	var a := TAU * (side % sides) / sides
	var point := Vector3(cos(a) * level.y, level.x, sin(a) * level.z + level.w)
	if sculpt and sin(a) < 0.0:
		var x := point.x
		var y := point.y
		var front := smoothstep(.36, .86, -sin(a))
		var nose_x := x - .0019 * (1.0 - smoothstep(.139, .184, y))
		var bridge := .018 * _falloff(nose_x, (y-.166)*.69, .0145)
		var tip := .028 * _falloff(nose_x, (y-.145)*1.12, .0121)
		var wings := .012 * _falloff(absf(nose_x)-.010, (y-.138)*1.24, .0091)
		var socket := .014 * _falloff(absf(x)-.038, (y-.175)*1.35, .0175)
		var brow := .0048 * _falloff(absf(x)-.038, (y-.190)*1.33, .020)
		var cheeks := .0058 * _falloff(absf(x)-.055, (y-.148)*1.14, .021)
		var mouth := .0055 * _falloff(x-.001, (y-.108)*1.7, .027)
		point.z += front * (socket - bridge - tip - wings - brow - cheeks - mouth)
	return point


static func _falloff(x: float, y: float, radius: float) -> float:
	var distance_squared := (x*x+y*y)/(radius*radius)
	return exp(-distance_squared)


static func _lapel_panel(side: float) -> ArrayMesh:
	var lapel := SurfaceTool.new()
	lapel.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Outer lapel roots sit inside the cloth near the shoulder; only the
	# turned wool face and narrow folded edge project over the waistcoat.
	var outline := [
		Vector3(side*.142,.485,-.096), Vector3(side*.077,.497,-.086),
		Vector3(side*.075,.432,-.142), Vector3(side*.079,.404,-.149),
		Vector3(side*.062,.239,-.151), Vector3(side*.119,.316,-.110),
		Vector3(side*.165,.453,-.085),
	]
	var fold := Vector3(side*.101,.415,-.131)
	for i in outline.size():
		var next := (i+1) % outline.size()
		var a: Vector3 = outline[i]
		var b: Vector3 = outline[next]
		var front := [fold,b,a] if side < 0.0 else [fold,a,b]
		for vertex: Vector3 in front:
			lapel.add_vertex(vertex)
		var a_back := a + Vector3.BACK*.014
		var b_back := b + Vector3.BACK*.014
		var edge := [a,b_back,a_back,a,b,b_back] if side < 0.0 else [a,a_back,b_back,a,b_back,b]
		for vertex: Vector3 in edge:
			lapel.add_vertex(vertex)
	lapel.generate_normals()
	return lapel.commit()
