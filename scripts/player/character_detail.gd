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
	for name in ["Jaw", "LeftEye", "RightEye"]:
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
		lapel.mesh = _cached_profile("lapels", [
			Vector4(-.5, .11, .3, 0), Vector4(-.42, .19, .40, 0),
			Vector4(-.08, .39, .40, 0), Vector4(.22, .50, .42, .01),
			Vector4(.49, .40, .36, .07)])
		lapel.scale.z = .012
		var collar: MeshInstance3D = upper.get_node(side + "Collar")
		collar.scale = Vector3(.073, .103, .032)
		collar.mesh = _cached_profile("collars", [
			Vector4(-.5,.16,.16,0), Vector4(-.25,.47,.44,0),
			Vector4(.16,.5,.49,.01), Vector4(.5,.25,.49,.08)])
		var arm: Node3D = upper.get_node(side + "ArmPivot")
		var sleeve: MeshInstance3D = arm.get_node("UpperSleeve")
		sleeve.mesh = _cached_profile("upper sleeve", [
			Vector4(-.5,.37,.38,0),Vector4(-.42,.42,.44,.02),Vector4(-.30,.38,.4,.008),
			Vector4(-.02,.46,.44,0),Vector4(.32,.49,.47,0),Vector4(.50,.46,.46,0)])
		var elbow: Node3D = arm.get_node("Elbow")
		var forearm: MeshInstance3D = elbow.get_node("ForeSleeve")
		forearm.mesh = _cached_profile("fore sleeve", [
			Vector4(-.5,.34,.35,0),Vector4(-.37,.39,.41,0),Vector4(-.20,.414,.415,0),
			Vector4(.14,.44,.43,-.021),Vector4(.34,.50,.48,.016),Vector4(.50,.45,.44,.032)])
		var cuff: MeshInstance3D = elbow.get_node("Cuff")
		cuff.mesh = _cached_profile("cuffs", [
			Vector4(-.5,.47,.47,0),Vector4(-.39,.50,.5,0),Vector4(.39,.50,.5,0),Vector4(.50,.45,.45,0)])
		cuff.scale = Vector3(.106,.041,.109)
		var joint := _part(elbow, "ElbowCloth", _sphere(), sleeve.material_override)
		joint.position.y = .003
		joint.scale = Vector3(.111,.101,.113)
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
	for name in ["Skull", "Nose", "Hair", "LeftEar", "RightEar"]:
		var part: MeshInstance3D = head.get_node(name)
		part.mesh = face[name]
		part.position = Vector3.ZERO
		part.scale = Vector3.ONE
		part.material_override = hair_material if name == "Hair" else skin_material
	head.get_node("Neck").material_override = skin_material
	head.get_node("Moustache").material_override = hair_material
	var moustache: MeshInstance3D = head.get_node("Moustache")
	moustache.mesh = _cached_batch("moustache", [
		[Vector3(-.20, 0, -.02), Vector3(.63,.71,.94), Vector3(0,0,-.19)],
		[Vector3(.20, 0, -.02), Vector3(.63,.71,.94), Vector3(0,0,.19)]])
	moustache.position = Vector3(0, .118, -.117)
	moustache.scale = Vector3(.063,.012,.025)
	var near := head.get_node_or_null("PortraitDetails") as MeshInstance3D
	if near == null:
		near = _part(head, "PortraitDetails", face["Details"], null)
		near.visibility_range_end = 15.0
		near.visibility_range_end_margin = 1.25
	else:
		near.mesh = face["Details"]


static func _make_face(character: int, skin: Color, hair_color: Color) -> Dictionary:
	var width: float = [1.0, 1.08, .93, 1.02, .96, 1.01][character]
	var chin: float = [1.0, 1.20, .93, 1.13, .84, 1.05][character]
	var head_mesh := _profile([
		Vector4(.066,.033 * chin,.041,-.031),Vector4(.075,.049 * chin,.058,-.031),
		Vector4(.093,.058 * chin,.074,-.022),Vector4(.119,.064 * chin,.082,-.017),
		Vector4(.147,.080 * width,.088,-.008),Vector4(.171,.080 * width,.090,-.004),
		Vector4(.191,.079 * width,.092,-.005),Vector4(.222,.077 * width,.091,.003),
		Vector4(.249,.054 * width,.066,.004),Vector4(.267,.007,.012,.01)], 22)
	var nose := _batch([
		[Vector3(0,.161,-.101),Vector3(.024,.046,.031),Vector3(-.34,0,0)],
		[Vector3(0,.148,-.119),Vector3(.024,.023,.031),Vector3.ZERO],
		[Vector3(-.010,.140,-.111),Vector3(.015,.012,.021),Vector3.ZERO],
		[Vector3(.010,.140,-.111),Vector3(.015,.012,.021),Vector3.ZERO]])
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
	var eye: Array = []
	var iris: Array = []
	var skin_details: Array = []
	var lips: Array = [
		[Vector3(0,.111,-.104),Vector3(.048,.007,.012),Vector3.ZERO],
		[Vector3(0,.104,-.101),Vector3(.042,.008,.013),Vector3.ZERO],
	]
	var shadows: Array = [
		[Vector3(0,.109,-.111),Vector3(.045,.0028,.005),Vector3.ZERO],
	]
	for side in [-1.0, 1.0]:
		var x: float = side * .038
		var eye_y := .174 if character == 5 else .177
		var angle := Vector3(0, -side * .32, side * .10)
		eye.append([Vector3(x,eye_y,-.087),Vector3(.026,.010,.016),angle])
		iris.append([Vector3(x-.001,eye_y,-.093),Vector3(.010,.010,.005),angle])
		shadows.append([Vector3(x-.001,eye_y+.0006,-.0965),Vector3(.0059,.0065,.0038),angle])
		skin_details.append([Vector3(x,eye_y+.0055,-.089),Vector3(.030,.006,.012),angle])
		skin_details.append([Vector3(x,eye_y-.004,-.088),Vector3(.028,.005,.010),angle])
		temples.append([Vector3(x,.191,-.087),Vector3(.036,.007,.010),Vector3(0,-side*.28,side*.14)])
		lips.append([Vector3(side * .083 * width,.154,-.001),Vector3(.012,.026,.017),Vector3(0,0,-side*.21)])
		shadows.append([Vector3(side*.009,.137,-.119),Vector3(.008,.0038,.006),Vector3.ZERO])
	var details := ArrayMesh.new()
	_append_batch(details, eye, Materials.get_material(Color("#c9bdab")))
	_append_batch(details, iris, Materials.get_material(Color("#536467") if character % 2 == 0 else Color("#654e3c")))
	_append_batch(details, shadows, Materials.get_material(Color("#31201d")))
	_append_batch(details, lips, Materials.get_material(skin.darkened(.20).lerp(Color("#a75854"), .32), Materials.Finish.SKIN))
	_append_batch(details, skin_details, Materials.get_material(skin.darkened(.08), Materials.Finish.SKIN))
	_append_batch(details, temples, Materials.get_material(hair_color, Materials.Finish.HAIR))
	var ears: Dictionary = {}
	for side in [-1.0, 1.0]:
		ears["LeftEar" if side < 0.0 else "RightEar"] = _batch([
			[Vector3(side*.078*width,.158,.004),Vector3(.025,.051,.029),Vector3(.14,0,-side*.16)],
			[Vector3(side*.082*width,.145,-.001),Vector3(.014,.018,.020),Vector3.ZERO]])
	return {"Skull": head_mesh, "Nose": nose, "Hair": _batch(locks), "LeftEar": ears.LeftEar,
		"RightEar": ears.RightEar, "Details": details}


static func _hands(elbow: Node3D, side: float, skin: Color) -> void:
	var hand: MeshInstance3D = elbow.get_node("Hand")
	var fingers: Array = [
		[Vector3(0,.04,0),Vector3(.90,.75,.75),Vector3.ZERO],
		[Vector3(0,.38,.015),Vector3(.65,.38,.63),Vector3.ZERO],
	]
	for index in 4:
		var x := (index - 1.5) * .211
		var length: float = [.39,.48,.44,.34][index]
		fingers.append([Vector3(x,-.32,-.101),Vector3(.28,length,.44),Vector3(.13,0,side*(index-1.5)*.045)])
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


static func _profile(levels: Array, sides: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for level in range(levels.size() - 1):
		for side in sides:
			var a := _ring(levels[level], side, sides)
			var b := _ring(levels[level], side+1, sides)
			var c := _ring(levels[level+1], side+1, sides)
			var d := _ring(levels[level+1], side, sides)
			for point: Vector3 in [a,b,c,a,c,d]:
				surface.add_vertex(point)
	var first: Vector4 = levels.front()
	var last: Vector4 = levels.back()
	for side in sides:
		for point: Vector3 in [Vector3(0,first.x,first.w),_ring(first,side+1,sides),_ring(first,side,sides),
				Vector3(0,last.x,last.w),_ring(last,side,sides),_ring(last,side+1,sides)]:
			surface.add_vertex(point)
	surface.generate_normals()
	surface.index()
	return surface.commit()


static func _ring(level: Vector4, side: int, sides: int) -> Vector3:
	var a := TAU * (side % sides) / sides
	return Vector3(cos(a) * level.y, level.x, sin(a) * level.z + level.w)
