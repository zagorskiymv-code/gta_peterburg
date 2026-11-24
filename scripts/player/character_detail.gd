extends RefCounted

const Materials = preload("res://scripts/player/character_materials.gd")

const Head = preload("res://scripts/player/character_head.gd")

static var _meshes: Dictionary = {}
static var _faces: Dictionary = {}


static func apply(visual: Node3D) -> void:
	var upper: Node3D = visual.get_node("Body/UpperBody")
	var head: Node3D = upper.get_node("Head")
	var player_skin := Color("#ad785e")
	var hair := Color("#413026")
	var leather := Materials.get_material(Color("#32271f"), Materials.Finish.LEATHER)
	var felt := Materials.get_material(Color("#292729"), Materials.Finish.FELT)
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
					tint = Color("#2d3840").lightened(.035)
				"Waistcoat":
					tint = Color("#664d36")
				"Shirt":
					tint = Color("#ddd6c5")
					finish = Materials.Finish.COTTON
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
	neck.mesh = _cached_profile("neck", [
		Vector4(-.50,.49,.48,.03), Vector4(-.28,.47,.46,.02),
		Vector4(.05,.45,.45,.025), Vector4(.25,.46,.46,.022),
		Vector4(.46,.49,.49,.003), Vector4(.50,.46,.45,0)])
	for name in ["BowlerCrown", "BowlerBrim"]:
		head.get_node(name).material_override = felt
	var crown: MeshInstance3D = head.get_node("BowlerCrown")
	if not _meshes.has("bowler crown"):
		_meshes["bowler crown"] = _profile([
			Vector4(-.50,.46,.46,0), Vector4(-.43,.49,.48,0),
			Vector4(-.17,.49,.48,.006), Vector4(.08,.45,.44,.013),
			Vector4(.29,.36,.36,.021), Vector4(.44,.23,.22,.023),
			Vector4(.49,.102,.105,.025), Vector4(.50,.006,.006,.025)], 32)
		_meshes["bowler brim"] = _bowler_brim()
	crown.mesh = _meshes["bowler crown"]
	crown.position.y = .295
	crown.scale.y = .120
	var brim: MeshInstance3D = head.get_node("BowlerBrim")
	brim.set_meta(&"solid_brim", brim.mesh)
	brim.mesh = _meshes["bowler brim"]
	head.get_node("BowlerBrim").scale.y = .014
	var bowler_band: MeshInstance3D = head.get_node("BowlerBand")
	bowler_band.position.y = .246
	bowler_band.scale = Vector3(.196, .019, .211)
	bowler_band.mesh = _cached_profile("bowler ribbon", [
		Vector4(-.50,.495,.495,0), Vector4(-.40,.500,.50,0),
		Vector4(.40,.498,.50,.004), Vector4(.50,.490,.494,.004)])
	var collar_band: MeshInstance3D = head.get_node("ShirtCollar")
	collar_band.scale.y *= .78
	collar_band.mesh = _cached_profile("stand shirt collar", [
		Vector4(-.50,.53,.55,0), Vector4(-.35,.52,.54,0),
		Vector4(.35,.49,.51,0), Vector4(.50,.48,.49,0)])

	var knot: MeshInstance3D = upper.get_node("Cravat")
	if not _meshes.has("folded cravat"):
		_meshes["folded cravat"] = _front_panel([
			Vector4(.376,.003,-.157,.003), Vector4(.390,.024,-.164,.007),
			Vector4(.451,.019,-.160,.005), Vector4(.484,.012,-.144,.004),
			Vector4(.492,.011,-.140,.004), Vector4(.500,.017,-.143,.010),
			Vector4(.519,.020,-.126,.010), Vector4(.532,.017,-.105,.009)])
	knot.mesh = _meshes["folded cravat"]
	knot.transform = Transform3D.IDENTITY
	knot.material_override = Materials.get_material(Color("#49392f"), Materials.Finish.WOOL)
	var torso: MeshInstance3D = upper.get_node("CoatTorso")
	if not _meshes.has("cut jacket"):
		_meshes["cut jacket"] = _coat_shell()
		_meshes["waistcoat front"] = _front_panel([
			Vector4(-.59,.41,-.095,.18), Vector4(-.29,.52,-.18,.33),
			Vector4(.07,.51,-.23,.34), Vector4(.28,.49,-.18,.32),
			Vector4(.40,.37,-.12,.26), Vector4(.48,.21,-.066,.19)])
		_meshes["shirt front"] = _front_panel([
			Vector4(-.20,.025,-.12,.10), Vector4(-.02,.12,-.18,.20),
			Vector4(.23,.19,-.11,.25), Vector4(.48,.25,.27,.32),
			Vector4(.66,.36,.62,.34), Vector4(.81,.35,1.14,.34),
			Vector4(.94,.28,1.57,.30)])
	torso.mesh = _meshes["cut jacket"]
	torso.set_meta(&"closed_cut", _cached_profile("closed uniform", COAT_RINGS))
	var jacket_lining: MeshInstance3D = upper.get_node("CoatShoulders")
	jacket_lining.mesh = _cached_profile("jacket lining", COAT_RINGS)
	jacket_lining.position = Vector3(0,.275,.013)
	jacket_lining.scale = Vector3(.405,.475,.245)
	jacket_lining.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	upper.get_node("Waistcoat").mesh = _meshes["waistcoat front"]
	upper.get_node("ShirtFront").mesh = _meshes["shirt front"]
	upper.get_node("Waistcoat").position.z = -.139
	upper.get_node("ShirtFront").position.z = -.144
	upper.get_node("ShirtFront").position.y = .420
	upper.get_node("BackWaistSeam").hide()
	upper.get_node("BackVent").hide()
	for i in 4:
		var button: MeshInstance3D = upper.get_node("WaistcoatButton%d" % i)
		button.position.z = -.152
		button.scale *= .81
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
		var collar_key := "%s collar fold" % side
		if not _meshes.has(collar_key):
			_meshes[collar_key] = _collar_fold(mirror)
		collar.mesh = _meshes[collar_key]
		collar.transform = Transform3D.IDENTITY
		var welt: MeshInstance3D = upper.get_node(side + "PocketWelt")
		welt.mesh = _cached_profile("welt pocket", [
			Vector4(-.48,.39,.39,0), Vector4(-.30,.49,.48,0),
			Vector4(.30,.49,.48,0), Vector4(.48,.40,.34,0)])
		welt.position = Vector3(mirror*.124,.083,-.109)
		welt.scale = Vector3(.087,.011,.015)
		welt.rotation_degrees = Vector3(0,mirror*29,mirror*4)

		var arm: Node3D = upper.get_node(side + "ArmPivot")
		var elbow: Node3D = arm.get_node("Elbow")
		_fit_sleeve(arm, elbow, mirror)
		var cuff: MeshInstance3D = elbow.get_node("Cuff")
		cuff.mesh = _cached_profile("cuffs", [
			Vector4(-.5,.47,.47,0),Vector4(-.39,.50,.5,0),Vector4(.39,.50,.5,0),Vector4(.50,.45,.45,0)])
		cuff.scale = Vector3(.106,.041,.109)
		_hands(elbow, mirror, player_skin)

		var leg: Node3D = visual.get_node("Body/" + side + "LegPivot")
		var thigh: MeshInstance3D = leg.get_node("Thigh")
		thigh.scale.x *= 1.06
		thigh.mesh = _cached_profile("pressed thigh", [
			Vector4(-.59,.367,.39,-.012),Vector4(-.53,.399,.421,-.009),Vector4(-.46,.426,.448,.002),
			Vector4(-.31,.444,.455,-.006),Vector4(.12,.48,.47,0),
			Vector4(.40,.48,.46,.021),Vector4(.50,.44,.43,.020)])
		var knee: Node3D = visual.get_node("Body/" + side + "LegPivot/Knee")
		var trouser: MeshInstance3D = knee.get_node("TrouserLeg")
		trouser.scale.x *= 1.12
		trouser.mesh = _cached_profile("trousers", [
			Vector4(-.5,.39,.39,0),Vector4(-.33,.43,.39,.008),Vector4(.12,.46,.46,-.005),
			Vector4(.31,.48,.47,-.025),Vector4(.43,.49,.48,-.035),Vector4(.51,.49,.47,-.012)])
		knee.get_node("BootShaft").hide()
		_shoe(knee.get_node("Ankle"), leather)

	_add_detail_ranges(visual)
	configure_face(head, 0, player_skin, hair)


static func _fit_sleeve(arm: Node3D, elbow: Node3D, side: float) -> void:
	var sleeve: MeshInstance3D = arm.get_node("UpperSleeve")
	var joint := elbow.position
	var key := "tailored sleeve %s" % side
	if not _meshes.has(key):
		_meshes[key] = _weighted_sleeve(joint.y, side)
		var skin := Skin.new()
		skin.add_bind(0, Transform3D.IDENTITY)
		skin.add_bind(1, Transform3D(Basis.IDENTITY,-joint))
		_meshes[key+" skin"] = skin
	var rig := Skeleton3D.new()
	rig.name = "SleeveRig"
	arm.add_child(rig)
	rig.add_bone("UpperArm")
	rig.add_bone("Forearm")
	rig.set_bone_parent(1,0)
	rig.set_bone_rest(1,Transform3D(Basis.IDENTITY,joint))
	rig.set_bone_pose_position(1,joint)
	sleeve.transform = Transform3D.IDENTITY
	sleeve.mesh = _meshes[key]
	sleeve.skin = _meshes[key+" skin"]
	sleeve.skeleton = sleeve.get_path_to(rig)
	arm.get_node("Shoulder").hide()
	elbow.get_node("ForeSleeve").hide()


static func _weighted_sleeve(joint_y: float, side: float) -> ArrayMesh:
	var sections := [
		Vector4(-.492,.035,.036,0), Vector4(-.463,.046,.048,-.002),
		Vector4(-.415,.050,.052,-.003), Vector4(-.325,.053,.054,-.003),
		Vector4(-.289,.055,.055,-.001), Vector4(-.264,.053,.056,.001),
		Vector4(-.242,.056,.057,.001), Vector4(-.211,.057,.057,.003),
		Vector4(-.164,.062,.061,.003), Vector4(-.094,.067,.065,.002),
		Vector4(-.018,.066,.066,.004), Vector4(.024,.056,.061,.005),
		Vector4(.057,.039,.052,.006), Vector4(.070,.023,.029,.008),
	]
	var rows: Array[PackedVector3Array] = []
	for section: Vector4 in sections:
		var row := PackedVector3Array()
		for segment in 16:
			var point := _ring(section,segment,16)
			point.x -= side*.034*smoothstep(-.22,.069,point.y)
			row.append(point)
		rows.append(row)
	var geometry := Head.mesh_rings(rows,true,true)
	var arrays := geometry.surface_get_arrays(0)
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
		var forearm := 1.0 - smoothstep(joint_y-.072,joint_y+.065,vertex.y)
		bones.append_array(PackedInt32Array([0,1,0,0]))
		weights.append_array(PackedFloat32Array([1.0-forearm,forearm,0.0,0.0]))
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	var deformable := ArrayMesh.new()
	deformable.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],
		Head.ring_lods(rows.size(),16,true,true))
	return deformable


static func _add_detail_ranges(visual: Node3D) -> void:
	for detail: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
		if "Button" in detail.name or "PocketWelt" in detail.name or detail.name == "VampCreases":
			detail.visibility_range_end = 12.0
			detail.visibility_range_end_margin = 1.5
			detail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif detail.name in ["BowlerBand", "ShirtCuff", "StackedHeel", "Thumb"]:
			detail.visibility_range_end = 19.0
			detail.visibility_range_end_margin = 2.0


static func configure_face(head: Node3D, character: int, skin: Color, hair_color: Color) -> void:
	if not _faces.has(character):
		_faces[character] = {
			"Skull": Head.make_skull(character), "Hair": Head.hair(character),
			"LeftEar": Head.ear(character, -1.0), "RightEar": Head.ear(character, 1.0),
			"Moustache": Head.moustache(character), "Eyebrows": Head.eyebrows(character), "Eyes": {},
		}
	var face: Dictionary = _faces[character]
	var skin_material := Materials.get_material(skin, Materials.Finish.SKIN)
	var face_material := Materials.get_material(skin, Materials.Finish.FACE)
	var hair_material := Materials.get_material(hair_color, Materials.Finish.HAIR)
	for part_name in ["Skull", "Hair", "LeftEar", "RightEar", "Moustache"]:
		var part: MeshInstance3D = head.get_node(part_name)
		part.mesh = face[part_name]
		part.position = Vector3(0, .120, -.104) if part_name == "Moustache" else Vector3.ZERO
		part.scale = Vector3.ONE
		part.material_override = hair_material if part_name in ["Hair", "Moustache"] else skin_material
		if part_name == "Skull":
			part.material_override = face_material
	var eyebrows := head.get_node_or_null("Eyebrows") as MeshInstance3D
	var brow_material := Materials.get_material(hair_color.lightened(.025), Materials.Finish.HAIR)
	if eyebrows == null:
		eyebrows = _part(head, "Eyebrows", face["Eyebrows"], brow_material)
		eyebrows.visibility_range_end = 12.0
		eyebrows.visibility_range_end_margin = 2.0
	else:
		eyebrows.mesh = face["Eyebrows"]
		eyebrows.material_override = brow_material
	head.get_node("Neck").material_override = skin_material
	var eye_key := skin.to_html(false)
	var eye_frames: Dictionary = face["Eyes"]
	if not eye_frames.has(eye_key):
		var iris_colors := [Color("#524338"), Color("#524338"), Color("#485559"),
			Color("#504936"), Color("#4c4a38"), Color("#4c5547")]
		var eyes := Materials.get_material(iris_colors[character], Materials.Finish.EYE)
		var frames: Array[ArrayMesh] = []
		for frame in 5:
			frames.append(Head.eyes(character, eyes, skin_material, frame / 4.0))
		eye_frames[eye_key] = frames
	var near := head.get_node_or_null("PortraitDetails") as MeshInstance3D
	if near == null:
		near = _part(head, "PortraitDetails", eye_frames[eye_key][0], null)
		near.visibility_range_end = 17.0
		near.visibility_range_end_margin = 2.0
	else:
		near.mesh = eye_frames[eye_key][0]
	near.set_meta(&"eye_frames", eye_frames[eye_key])


static func _hands(elbow: Node3D, side: float, skin: Color) -> void:
	var hand: MeshInstance3D = elbow.get_node("Hand")
	if not _meshes.has("articulated palm"):
		_meshes["articulated palm"] = _palm()
	hand.mesh = _meshes["articulated palm"]
	hand.scale = Vector3.ONE
	var thumb: MeshInstance3D = elbow.get_node("Thumb")
	thumb.mesh = _cached_profile("thumb taper", [
		Vector4(-.50,.17,.19,-.15), Vector4(-.39,.40,.39,-.10),
		Vector4(-.14,.43,.41,-.045), Vector4(.18,.49,.49,0),
		Vector4(.39,.44,.42,.08), Vector4(.50,.31,.29,.08)])
	thumb.position.x = -side*.022
	thumb.rotation.z = -side*.31
	thumb.scale = Vector3(.022,.048,.025)
	for part: MeshInstance3D in [hand, thumb]:
		part.material_override = Materials.get_material(skin, Materials.Finish.SKIN)


static func _palm() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var roots: Array[PackedVector3Array] = []
	var lengths := [.027,.033,.031,.024]
	var knuckles := [.000,-.002,-.001,.002]
	for digit in 4:
		var center := (digit-1.5)*.014
		var previous := PackedVector3Array()
		for i in 4:
			var progress := i/3.0
			var ring := PackedVector3Array()
			for j in 6:
				var angle := TAU*j/6.0
				var taper: float = [1.0,.90,.73,.27][i]
				ring.append(Vector3(center+cos(angle)*.007*taper+center*.14*progress,
					-.013+knuckles[digit]-lengths[digit]*progress,
					sin(angle)*.010*taper-.012*progress*progress))
			if i == 0:
				roots.append(ring)
			else:
				for j in 6:
					var k := (j+1)%6
					_cloth_quad(tool, ring[j], ring[k], previous[k], previous[j], false)
			previous = ring
		for j in range(1,5):
			for point in [previous[0],previous[j+1],previous[j]]:
				tool.add_vertex(point)
	# The ring around the palm shares its border with all four finger roots.
	var edge := PackedVector3Array()
	for digit in range(3,-1,-1):
		for j in range(0,3):
			edge.append(roots[digit][j])
	edge.append(roots[0][3])
	for digit in 4:
		for j in [4,5,0]:
			if digit != 3 or j != 0:
				edge.append(roots[digit][j])
	var lower := edge
	for i in [1,2,3]:
		var upper := PackedVector3Array()
		for point in edge:
			var angle := atan2(point.z/.011,point.x/.029)
			var width: float = [.029,.026,.021][i-1]
			var depth: float = [.013,.014,.012][i-1]
			var height: float = [.002,.023,.042][i-1]
			upper.append(Vector3(cos(angle)*width,height,sin(angle)*depth))
		for j in edge.size():
			var k := (j+1)%edge.size()
			_cloth_quad(tool,lower[j],lower[k],upper[k],upper[j],false)
		lower = upper
	tool.generate_normals()
	tool.index()
	return tool.commit()


static func _shoe(ankle: Node3D, leather: Material) -> void:
	var upper: MeshInstance3D = ankle.get_node("BootUpper")
	upper.mesh = _cached_profile("boot upper", [
		Vector4(-.084,.064,.116,-.060),Vector4(-.074,.068,.119,-.059),
		Vector4(-.057,.063,.117,-.060),Vector4(-.034,.058,.100,-.049),
		Vector4(-.015,.055,.074,-.033),Vector4(.015,.053,.059,-.010),
		Vector4(.041,.052,.054,.001),Vector4(.073,.050,.054,.001),
		Vector4(.100,.051,.051,.002),Vector4(.116,.046,.047,.002)])
	upper.position = Vector3.ZERO
	upper.scale = Vector3.ONE
	upper.material_override = leather
	ankle.get_node("Toe").hide()
	var sole: MeshInstance3D = ankle.get_node("Sole")
	sole.mesh = _cached_profile("soles", [
		Vector4(-.105,.058,.108,-.059),Vector4(-.101,.065,.121,-.057),
		Vector4(-.088,.069,.122,-.058),Vector4(-.081,.065,.119,-.058)])
	sole.position = Vector3.ZERO
	sole.scale = Vector3.ONE
	sole.material_override = Materials.get_material(Color("#261e19"), Materials.Finish.LEATHER)
	var heel := _part(ankle, "StackedHeel", _cached_profile("stacked heel", [
		Vector4(-.108,.042,.040,.023), Vector4(-.104,.049,.044,.023),
		Vector4(-.093,.050,.047,.023)]), sole.material_override)
	heel.visibility_range_end = 18.0
	if not _meshes.has("laces"):
		_meshes["laces"] = _laces()
	var vamp := _part(ankle, "VampCreases", _meshes["laces"],
		Materials.get_material(Color("#423328"), Materials.Finish.LEATHER))
	vamp.visibility_range_end = 12.0


static func _laces() -> ArrayMesh:
	var lace := SurfaceTool.new()
	lace.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 3:
		var z := -.075-row*.0115
		for section in 8:
			var u := section/4.0-1.0
			var v := (section+1)/4.0-1.0
			var a := Vector3(.030*u,-.019-row*.006-.011*u*u,z)
			var b := Vector3(.030*v,-.019-row*.006-.011*v*v,z)
			var thickness := Vector3(0,.001,.0028)
			_cloth_quad(lace,a,b,b+thickness,a+thickness,false)
	lace.generate_normals()
	lace.index()
	return lace.commit()


static func _part(parent: Node3D, name: String, mesh: Mesh, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = name
	part.mesh = mesh
	part.material_override = material
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	return part


static func _coat_tails() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := [
		Vector4(-.50,.50,.57,.015), Vector4(-.456,.518,.57,.015),
		Vector4(-.30,.499,.546,.012), Vector4(.03,.472,.49,.003),
		Vector4(.27,.439,.45,-.01), Vector4(.50,.409,.435,-.006),
	]
	for side in 2:
		# Each side is a separate panel, with an open front and a back vent.
		for level in range(rings.size() - 1):
			for j in 10:
				var a := _skirt_edge(rings[level],side,j/10.0)
				var b := _skirt_edge(rings[level],side,(j+1)/10.0)
				var c := _skirt_edge(rings[level+1],side,(j+1)/10.0)
				var d := _skirt_edge(rings[level+1],side,j/10.0)
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


static func _skirt_edge(ring: Vector4, side: int, across: float) -> Vector3:
	var front_opening := lerpf(.24,.025,smoothstep(-.5,.40,ring.x))
	var back_vent := lerpf(.10,.0,smoothstep(-.5,.22,ring.x))
	var start := (-PI/2.0 + front_opening) if side == 0 else (PI/2.0 + back_vent)
	var end := (PI/2.0 - back_vent) if side == 0 else (3.0*PI/2.0 - front_opening)
	return _tail_vertex(ring,lerpf(start,end,across))


static func _tail_vertex(ring: Vector4, angle: float) -> Vector3:
	return Vector3(cos(angle)*ring.y, ring.x, sin(angle)*ring.z+ring.w)


static func _cached_profile(key: String, levels: Array) -> ArrayMesh:
	if not _meshes.has(key):
		_meshes[key] = _profile(levels, 16)
	return _meshes[key]


static func _profile(levels: Array, sides: int) -> ArrayMesh:
	var rows: Array[PackedVector3Array] = []
	for level: Vector4 in levels:
		var row := PackedVector3Array()
		for side in sides:
			row.append(_ring(level,side,sides))
		rows.append(row)
	return Head.mesh_rings(rows, true, true)


static func _ring(level: Vector4, side: int, sides: int) -> Vector3:
	var a := TAU * (side % sides) / sides
	return Vector3(cos(a) * level.y, level.x, sin(a) * level.z + level.w)


const COAT_RINGS := [
	Vector4(-.50,.442,.500,.005), Vector4(-.36,.431,.489,.012),
	Vector4(-.12,.444,.512,.006), Vector4(.12,.469,.541,-.006),
	Vector4(.30,.503,.507,-.004), Vector4(.43,.475,.438,.011),
	Vector4(.52,.412,.371,.022), Vector4(.58,.229,.275,.029),
]
const COAT_OPENING := [.095,.098,.14,.25,.42,.50,.52,.58]


static func _coat_shell() -> ArrayMesh:
	var rows: Array[PackedVector3Array] = []
	for section in COAT_RINGS.size():
		var row := PackedVector3Array()
		for corner in 33:
			row.append(_coat_point(section,corner/32.0))
		rows.append(row)
	return Head.mesh_rings(rows, true, false, false)


static func _coat_point(row: int, fraction: float) -> Vector3:
	var section: Vector4 = COAT_RINGS[row]
	var slit: float = COAT_OPENING[row]
	var angle := -PI/2.0 + slit + (TAU-2.0*slit)*fraction
	var point := _tail_vertex(section,angle)
	# A shallow pressed seam follows the back beneath the shoulder blades.
	var back_seam := 1.0-smoothstep(0.0,.041,absf(fraction-.5))
	point.z -= .007*back_seam*(1.0-smoothstep(.27,.58,section.x))
	return point


static func _coat_edge(row: int, side: float, inset: float) -> Vector3:
	var fraction := inset if side > 0.0 else 1.0-inset
	return Vector3(0,.275,.007) + _coat_point(row,fraction)*Vector3(.423,.48,.269)


static func _lapel_panel(side: float) -> ArrayMesh:
	var fold := SurfaceTool.new()
	fold.begin(Mesh.PRIMITIVE_TRIANGLES)
	var roots: Array[Vector3] = []
	var hems: Array[Vector3] = []
	var widths := [.001,.009,.019,.036,.043,.024]
	for row in range(2,8):
		var root := _coat_edge(row,side,.022) + Vector3.FORWARD*.003
		var hem := _coat_edge(row,side,0.0) + Vector3(-side*widths[row-2],
			.003*smoothstep(3.0,6.0,row),-.005)
		roots.append(root)
		hems.append(hem)
	for i in range(5):
		_cloth_quad(fold, roots[i], hems[i], hems[i+1], roots[i+1], side > 0.0)
		var lining := Vector3.BACK*.0025
		_cloth_quad(fold, hems[i], hems[i]+lining, hems[i+1]+lining, hems[i+1], side > 0.0)
	fold.generate_normals()
	fold.index()
	return fold.commit()


static func _collar_fold(side: float) -> ArrayMesh:
	var cloth := SurfaceTool.new()
	cloth.begin(Mesh.PRIMITIVE_TRIANGLES)
	var notch := _coat_edge(6,side,.017) + Vector3.FORWARD*.004
	var neck := Vector3(side*.052,.552,-.031)
	var back := Vector3(side*.061,.545,.035)
	var shoulder := _coat_edge(6,side,.048) + Vector3.FORWARD*.003
	_cloth_quad(cloth, shoulder, notch, neck, back, side > 0.0)
	_cloth_quad(cloth, shoulder, shoulder+Vector3.DOWN*.003,
		notch+Vector3.DOWN*.003, notch, side > 0.0)
	cloth.generate_normals()
	cloth.index()
	return cloth.commit()


static func _front_panel(sections: Array) -> ArrayMesh:
	var panel := SurfaceTool.new()
	panel.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(sections.size()-1):
		var a: Vector4 = sections[i]
		var b: Vector4 = sections[i+1]
		for step in range(-2,2):
			var left := step/2.0
			var right := (step+1)/2.0
			_cloth_quad(panel, _panel_point(a,left), _panel_point(a,right),
				_panel_point(b,right), _panel_point(b,left), false)
	panel.generate_normals()
	panel.index()
	return panel.commit()


static func _panel_point(section: Vector4, across: float) -> Vector3:
	return Vector3(section.y*across,section.x,section.z+section.w*across*across)


static func _cloth_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		d: Vector3, flipped: bool) -> void:
	var vertices := [a,c,b,a,d,c] if flipped else [a,b,c,a,c,d]
	for point: Vector3 in vertices:
		surface.add_vertex(point)


static func _bowler_brim() -> ArrayMesh:
	var brim := SurfaceTool.new()
	brim.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 32:
		var a := TAU*i/32.0
		var b := TAU*(i+1)/32.0
		var inner_a := _brim_point(a,.32)
		var inner_b := _brim_point(b,.32)
		var outer_a := _brim_point(a,.50)
		var outer_b := _brim_point(b,.50)
		var depth := Vector3.DOWN*.21
		_cloth_quad(brim, inner_a, outer_a, outer_b, inner_b, false)
		_cloth_quad(brim, inner_a+depth, outer_a+depth, outer_b+depth, inner_b+depth, true)
		_cloth_quad(brim, outer_a, outer_a+depth, outer_b+depth, outer_b, false)
	brim.generate_normals()
	brim.index()
	return brim.commit()


static func _brim_point(angle: float, radius: float) -> Vector3:
	var sweep := smoothstep(.32,.50,radius)
	var curl := .29*pow(absf(cos(angle)),2.8) - .075*pow(absf(sin(angle)),2.0)
	return Vector3(cos(angle)*radius,sweep*curl,sin(angle)*radius)
