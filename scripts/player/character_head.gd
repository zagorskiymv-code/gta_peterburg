extends RefCounted

# y, half-width, front depth and rear depth. Landmark rows describe the jaw,
# the zygomatic arch and the frontal bone independently of the eye openings.
const CRANIUM := [
	Vector4(.063,.031,.063,.040),Vector4(.073,.048,.079,.046),
	Vector4(.088,.058,.088,.055),Vector4(.105,.065,.093,.066),
	Vector4(.125,.073,.092,.078),Vector4(.147,.080,.091,.091),
	Vector4(.172,.081,.089,.101),Vector4(.191,.079,.095,.103),
	Vector4(.218,.077,.089,.096),Vector4(.239,.065,.077,.075),
	Vector4(.256,.043,.053,.052),Vector4(.270,.006,.015,.014),
]
# y, bridge/tip projection, bridge width and extra projection of the alae.
const NOSE := [
	Vector4(.129,0,.010,0),Vector4(.136,.010,.016,.009),
	Vector4(.143,.024,.016,.007),Vector4(.149,.029,.015,.005),
	Vector4(.157,.026,.013,.001),Vector4(.169,.017,.011,0),
	Vector4(.181,.011,.009,0),Vector4(.196,0,.012,0),
]
const ROWS := [
	.063,.070,.078,.087,.096,.103,.108,.112,.117,.123,
	.130,.136,.140,.144,.148,.153,.159,.165,.170,.174,
	.178,.182,.187,.193,.201,.213,.226,.241,.256,.270,
]
const SHAPES := [
	Vector4(1,1,1,0), Vector4(1.06,1.17,1.02,-1),
	Vector4(.95,.91,1.09,1), Vector4(1.02,1.08,.94,-.5),
	Vector4(.96,.87,.87,.8), Vector4(.99,1.02,1.14,-.8),
]


static func make_skull(profile: int) -> ArrayMesh:
	var rows: Array[PackedVector3Array] = []
	for y: float in ROWS:
		var row := PackedVector3Array()
		for column in 48:
			row.append(head_point(y, _angle(column), profile))
		rows.append(row)
	return mesh_rings(rows, true, true)


static func _angle(column: int) -> float:
	# Two thirds of the samples are on the face and one third on the occiput.
	if column <= 32:
		return -PI/2.0 + PI*column/32.0
	return PI/2.0 + PI*(column-32)/16.0


static func _section(control: Array, y: float) -> Vector4:
	for i in range(1, control.size()):
		var after: Vector4 = control[i]
		if y <= after.x:
			var before: Vector4 = control[i-1]
			return before.lerp(after, clampf((y-before.x)/(after.x-before.x),0,1))
	return control.back()


static func head_point(y: float, angle: float, profile: int) -> Vector3:
	var section := _section(CRANIUM, y)
	var variant: Vector4 = SHAPES[profile]
	var jaw := 1.0 - smoothstep(.100,.154,y)
	var width := section.y * lerpf(variant.x, variant.y, jaw)
	var x := sin(angle) * width
	var front := cos(angle)
	var z := -front * (section.z if front >= 0.0 else section.w)
	if front > 0.0:
		z += _facial_section(x, y, front, variant)
	return Vector3(x,y,z)


static func face_at(x: float, y: float, profile: int) -> Vector3:
	var section := _section(CRANIUM,y)
	var variant: Vector4 = SHAPES[profile]
	var width := section.y * lerpf(variant.x,variant.y,1.0-smoothstep(.100,.154,y))
	return head_point(y, asin(clampf(x/width,-.999,.999)), profile)


static func _facial_section(x: float, y: float, front: float, variant: Vector4) -> float:
	var nose := _section(NOSE,y)
	var offset_x := x - .0008 * (1.0-smoothstep(.144,.19,y))
	var bridge := nose.y * exp(-pow(offset_x / (nose.z + .002), 2.0))
	var ala := nose.w * exp(-pow((absf(offset_x)-.010)/.007,2.0))
	var orbital_x := 1.0-smoothstep(.006,.027,absf(absf(x)-(.037+variant.w*.0012)))
	var orbital_y := smoothstep(.150,.174,y)*(1.0-smoothstep(.181,.198,y))
	var socket := .0065*orbital_x*orbital_y
	var muzzle := .0045*(1.0-smoothstep(.010,.029,absf(x))) * smoothstep(.093,.111,y)*(1.0-smoothstep(.120,.134,y))
	var lip_span := 1.0-smoothstep(.009,.026,absf(x))
	var lips := .0024 * lip_span * exp(-pow((y-.112)/.006,2.0))
	var cheek := .0030 * exp(-pow((absf(x)-.054)/.017,2.0) -pow((y-.152)/.021,2.0))
	return smoothstep(.27,.77,front) * (socket-(bridge+ala)*variant.z-muzzle-lips-cheek)


static func ear(profile: int, side: float) -> ArrayMesh:
	var rows: Array[PackedVector3Array] = []
	var root := head_point(.154, side*PI*.52, profile)
	# The first section is buried in the skull. Beyond the helix, the
	# sections return toward the concha to form a shallow outer bowl.
	for section: Vector2 in [Vector2(1.0,-.011),Vector2(1.0,.001),
			Vector2(.94,.009),Vector2(.72,.012),Vector2(.52,.0095),Vector2(.32,.007),Vector2(.08,.006)]:
		var ring := PackedVector3Array()
		for i in 16:
			var angle := side*TAU*i/16.0
			var vertical := sin(angle)
			var y := .154 + section.x*.024*vertical
			var z := root.z + section.x*(cos(angle)*.012 + vertical*.006)
			var fold := .0022 * sin(angle*2.0+.5) * smoothstep(.25,.8,section.x)
			var x := root.x + side*(section.y + section.x*vertical*.003 + fold)
			ring.append(Vector3(x,y,z))
		rows.append(ring)
	return mesh_rings(rows,false,true)


static func hair(profile: int) -> ArrayMesh:
	var rows: Array[PackedVector3Array] = []
	for level in 11:
		var row := PackedVector3Array()
		var height := maxf(0.0,(level-1)/9.0)
		for column in 48:
			var angle := wrapf(_angle(column),-PI,PI)
			var front := cos(angle)
			var line := lerpf(.158,.222,smoothstep(-.60,.76,front))
			line += .005*cos(3.0*angle)*smoothstep(.25,1.0,front)
			line -= .005*smoothstep(.45,1.0,-front)
			line -= .024 * (1.0-smoothstep(.025,.24,absf(absf(angle)-1.10)))
			line += .005*sin(angle)*smoothstep(-.1,1.0,front)
			if profile == 5:
				line += .012*smoothstep(.3,1.0,front)
			if profile == 4:
				line -= .010*(1.0-smoothstep(-.8,.1,front))
			var y := lerpf(line,.270,height)
			var point := head_point(y - (.0012 if level == 0 else 0.0), angle, profile)
			var part_angle := -.46 + .34*height
			var part := exp(-pow((angle-part_angle)/.11,2.0))*smoothstep(.05,.5,front)
			var wave := .0012*cos(11.0*angle + 5.0*height)
			var crown := (.0045 + .0025*sin(angle+.5))*smoothstep(.0,.42,height)
			var bulk := -.003 if level == 0 else lerpf(.0017,.0028,smoothstep(.0,.15,height))
			bulk += (crown + wave - part*.003)*sin(height*PI*.89)
			point += Vector3(sin(angle)*bulk, .008*smoothstep(.06,.92,height), -front*bulk)
			row.append(point)
		rows.append(row)
	return mesh_rings(rows,true,true)


static func eyebrows(profile: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-1.0,1.0]:
		for i in 12:
			for uv: Vector2 in [Vector2(0,-1),Vector2(1,-1),Vector2(1,1),
					Vector2(0,-1),Vector2(1,1),Vector2(0,1)]:
				var t := (i + (uv.x if side > 0.0 else 1.0-uv.x))/12.0
				var x: float = side*(.022 + .030*t + SHAPES[profile].w*.0012)
				var y := .189 + .004*sin(PI*t) - .003*t
				y += uv.y*(.0002 + .0015*pow(sin(PI*t),.65))
				var point := face_at(x,y,profile)
				point.z -= .0011
				surface.add_vertex(point)
	surface.generate_normals()
	surface.index()
	return surface.commit()


static func moustache(profile: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var origin := Vector3(0,.120,-.104)
	for side: float in [-1.0,1.0]:
		var points := PackedVector3Array()
		for i in 17:
			var t := i/16.0
			var a := Vector2(0,.121)
			var b := Vector2(.010,.122)
			var c := Vector2(.025,.116)
			var d := Vector2(.032,.120)
			var center := a.lerp(b,t).lerp(b.lerp(c,t),t).lerp(b.lerp(c,t).lerp(c.lerp(d,t),t),t)
			var width := .00035 + .00265*sin(PI * pow(t,.72))
			for edge: float in [-1.0,0.0,1.0]:
				var point := face_at(center.x*side,center.y+width*edge,profile)
				point.z -= .0015 + (.0012 if edge == 0.0 else 0.0)
				points.append(point-origin)
		for i in 16:
			for edge in 2:
				var a := points[i*3+edge]
				var b := points[(i+1)*3+edge]
				var c := points[(i+1)*3+edge+1]
				var d := points[i*3+edge+1]
				var order := [a,b,c,a,c,d] if side > 0.0 else [a,c,b,a,d,c]
				for point: Vector3 in order:
					surface.add_vertex(point)
	surface.generate_normals()
	surface.index()
	return surface.commit()


static func eyes(profile: int, eye_material: Material, lid_material: Material, blink: float) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var eye := SurfaceTool.new()
	eye.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lids := SurfaceTool.new()
	lids.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-1.0,1.0]:
		var center := Vector2(side*(.037 + SHAPES[profile].w*.0012),.176+side*.00065)
		for step in 16:
			var u := -1.0 + 2.0*step/16.0
			var v := -1.0 + 2.0*(step+1)/16.0
			if blink < 1.0:
				for band in 4:
					_eye_quad(eye, center, u, v, -1.0 + band*.5, -.5 + band*.5, profile, false, blink)
			_eye_quad(lids, center, u, v, 1.0, 2.0, profile, true, blink)
			_eye_quad(lids, center, u, v, -2.0, -1.0, profile, true, blink)
	if blink < 1.0:
		_commit_eye_surface(mesh,eye,eye_material)
	_commit_eye_surface(mesh,lids,lid_material)
	return mesh


static func _commit_eye_surface(mesh: ArrayMesh, tool: SurfaceTool, material: Material) -> void:
	tool.generate_normals()
	tool.index()
	var arrays := tool.commit_to_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var source: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var indices := PackedInt32Array()
	for i in range(0,source.size(),3):
		var a := source[i]
		var b := source[i+1]
		var c := source[i+2]
		if (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a]).length_squared() > 1e-20:
			indices.append_array(PackedInt32Array([a,b,c]))
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.surface_set_material(mesh.get_surface_count()-1,material)


static func _eye_quad(surface: SurfaceTool, center: Vector2, u: float, v: float,
		lower: float, upper: float, profile: int, lid: bool, blink: float) -> void:
	for coordinate: Vector2 in [Vector2(u,lower),Vector2(v,lower),Vector2(v,upper),
			Vector2(u,lower),Vector2(v,upper),Vector2(u,upper)]:
		var x := coordinate.x * .0119
		var r := sqrt(maxf(1.0-coordinate.x*coordinate.x,0))
		var side_y := (coordinate.y if not lid else clampf(coordinate.y,-1.0,1.0))
		var y := side_y * r * (.0037 if side_y > 0.0 else .0025)
		var outer := absf(coordinate.y) > 1.0
		if outer:
			y += signf(coordinate.y)*.0032*r
		var at := face_at(center.x+x,center.y+y+signf(center.x)*x*.05,profile)
		if not outer:
			var dome := sqrt(maxf(.012*.012 - (x*.85)*(x*.85) - y*y,0))
			at.z = minf(at.z-.0003, face_at(center.x,center.y,profile).z + .0099-dome)
			if lid:
				at.z -= .00045
		surface.set_uv(Vector2(.5+(x-.00035)/.024,.5+(y-.00025)/.024))
		if not outer:
			at.y = lerpf(at.y, center.y - .0014 + signf(center.x)*x*.05, blink * .995)
		surface.add_vertex(at)


static func mesh_rings(rows: Array[PackedVector3Array], use_lod := false,
		caps := false, closed := true) -> ArrayMesh:
	var width := rows[0].size()
	var vertices := PackedVector3Array()
	for row in rows:
		vertices.append_array(row)
	if caps:
		for end in [0,rows.size()-1]:
			var center := Vector3.ZERO
			for point in rows[end]:
				center += point / width
			vertices.append(center)
	var columns := width if closed else width-1
	var indices := _ring_indices(rows.size(), width, rows.size(), columns, caps, closed)
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	for i in range(0, indices.size(), 3):
		var a := indices[i]
		var b := indices[i+1]
		var c := indices[i+2]
		var normal := (vertices[c]-vertices[a]).cross(vertices[b]-vertices[a])
		normals[a] += normal
		normals[b] += normal
		normals[c] += normal
	for i in normals.size():
		normals[i] = normals[i].normalized()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	var lods := ring_lods(rows.size(),width,caps,closed) if use_lod else {}
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],lods)
	return mesh


static func ring_lods(height: int, width: int, caps: bool, closed: bool) -> Dictionary:
	var lods := {}
	var columns := width if closed else width-1
	var is_skull := width == 48 and height == 30
	var ring_counts := [18,10,6] if is_skull else [
		maxi(3, ceili(height*.72)), maxi(3, ceili(height*.52)), 3]
	var column_counts := [24,12,8] if is_skull else [
		maxi(8,columns >> 1), maxi(6,columns >> 2), maxi(5,columns >> 3)]
	var errors := [.003,.011,.029]
	for i in errors.size():
		var rings: int = mini(ring_counts[i],height)
		var segments: int = mini(column_counts[i],columns)
		if rings < height or segments < columns:
			lods[errors[i]] = _ring_indices(height,width,rings,segments,caps,closed)
	return lods


static func _ring_indices(height: int, width: int, ring_count: int,
		columns: int, caps: bool, closed: bool) -> PackedInt32Array:
	var indices := PackedInt32Array()
	var span := width if closed else width-1
	for row in range(ring_count-1):
		var lower := roundi(float(row)*(height-1)/(ring_count-1))*width
		var upper := roundi(float(row+1)*(height-1)/(ring_count-1))*width
		for col in columns:
			var a := floori(float(col)*span/columns)
			var b := floori(float(col+1)*span/columns)%width
			indices.append_array(PackedInt32Array([lower+a,lower+b,upper+b,lower+a,upper+b,upper+a]))
	if caps:
		var last := (height-1)*width
		var bottom := height*width
		for col in columns:
			var a := floori(float(col)*span/columns)
			var b := floori(float(col+1)*span/columns)%width
			indices.append_array(PackedInt32Array([bottom,b,a,bottom+1,last+a,last+b]))
	return indices
