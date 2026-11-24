extends RefCounted

# y, half-width, front depth and rear depth. Landmark rows describe the jaw,
# the zygomatic arch and the frontal bone independently of the eye openings.
const CRANIUM := [
	Vector4(.063,.035,.064,.037),Vector4(.073,.050,.082,.041),
	Vector4(.088,.061,.091,.051),Vector4(.105,.066,.093,.062),
	Vector4(.125,.073,.092,.078),Vector4(.147,.080,.091,.091),
	Vector4(.172,.081,.089,.101),Vector4(.191,.079,.095,.103),
	Vector4(.218,.077,.089,.096),Vector4(.239,.065,.077,.075),
	Vector4(.256,.043,.053,.052),Vector4(.270,.006,.015,.014),
]
# y, bridge/tip projection, bridge width and extra projection of the alae.
const NOSE := [
	Vector4(.129,0,.010,0),Vector4(.136,.010,.016,.009),
	Vector4(.143,.032,.015,.009),Vector4(.149,.035,.012,.003),
	Vector4(.157,.029,.010,0),Vector4(.169,.019,.009,0),
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
	var offset_x := x - .0016 * (1.0-smoothstep(.144,.19,y))
	var bridge := nose.y * (1.0-smoothstep(.002,nose.z+.008,absf(offset_x)))
	var ala := nose.w * (1.0-smoothstep(.001,.008,absf(absf(offset_x)-.010)))
	var orbital_x := 1.0-smoothstep(.006,.027,absf(absf(x)-(.037+variant.w*.0012)))
	var orbital_y := smoothstep(.150,.174,y)*(1.0-smoothstep(.181,.198,y))
	var socket := .011*orbital_x*orbital_y
	var muzzle := .0045*(1.0-smoothstep(.010,.029,absf(x))) * smoothstep(.093,.111,y)*(1.0-smoothstep(.120,.134,y))
	return smoothstep(.31,.78,front) * (socket-(bridge+ala)*variant.z-muzzle)


static func ear(profile: int, side: float) -> ArrayMesh:
	var shell: Array[PackedVector3Array] = []
	var root: Vector3 = head_point(.156, side*PI*.51, profile)
	for radius: float in [.08,.41,.76,1.0]:
		var ring := PackedVector3Array()
		for i in 14:
			var a := TAU*i/14.0
			var rim := sin(a)
			var y := .154 + radius*.027*rim
			var z := root.z + radius*(cos(a)*.015 + rim*.005)
			var x := root.x + side * (lerpf(.006,.013,smoothstep(.28,.81,radius)) + radius*rim*.004)
			if side < 0:
				z = root.z - (z-root.z)
			ring.append(Vector3(x,y,z))
		shell.append(ring)
	return mesh_rings(shell)


static func hair(profile: int) -> ArrayMesh:
	var rows: Array[PackedVector3Array] = []
	for level in 9:
		var row := PackedVector3Array()
		for column in 32:
			# The side part pushes the front hairline slightly to the right;
			# a shallow lobe ahead of each ear continues into the sideburn.
			var angle := -PI + TAU*column/32.0
			var front := cos(angle)
			var line := lerpf(.154,.224,smoothstep(-.50,.74,front))
			line -= .021 * (1.0-smoothstep(.04,.31,absf(absf(angle)-1.13)))
			line += .005*sin(angle)*smoothstep(-.1,1.0,front)
			if profile == 5:
				line += .012*smoothstep(.3,1.0,front)
			if profile == 4:
				line -= .010*(1.0-smoothstep(-.8,.1,front))
			var y := lerpf(line,.266,level/8.0)
			var point := head_point(y, angle, profile)
			var bulk := (.0020+.0010*sin(angle*5.0+level*.51)) * (1.0-level/10.0)
			point += Vector3(sin(angle)*bulk, .002, -front*bulk)
			row.append(point)
		rows.append(row)
	return mesh_rings(rows, true, true)


static func moustache(profile: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var origin := Vector3(0,.120,-.104)
	for side: float in [-1.0,1.0]:
		var points := PackedVector3Array()
		for i in 17:
			var t := i/16.0
			var a := Vector2(0,.121)
			var b := Vector2(.010,.123)
			var c := Vector2(.025,.114)
			var d := Vector2(.032,.120)
			var center := a.lerp(b,t).lerp(b.lerp(c,t),t).lerp(b.lerp(c,t).lerp(c.lerp(d,t),t),t)
			var width := .00065 + .0032*sin(PI * pow(t,.58))
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
			var u := -0.999 + 1.998*step/16.0
			var v := -0.999 + 1.998*(step+1)/16.0
			for band in 4:
				_eye_quad(eye, center, u, v, -1.0 + band*.5, -.5 + band*.5, profile, false, blink)
			_eye_quad(lids, center, u, v, 1.0, 2.0, profile, true, blink)
			_eye_quad(lids, center, u, v, -2.0, -1.0, profile, true, blink)
	eye.set_material(eye_material)
	eye.generate_normals()
	eye.index()
	eye.commit(mesh)
	lids.set_material(lid_material)
	lids.generate_normals()
	lids.index()
	lids.commit(mesh)
	return mesh


static func _eye_quad(surface: SurfaceTool, center: Vector2, u: float, v: float,
		lower: float, upper: float, profile: int, lid: bool, blink: float) -> void:
	for coordinate: Vector2 in [Vector2(u,lower),Vector2(v,lower),Vector2(v,upper),
			Vector2(u,lower),Vector2(v,upper),Vector2(u,upper)]:
		var x := coordinate.x * .0119
		var r := sqrt(maxf(1.0-coordinate.x*coordinate.x,0))
		var side_y := (coordinate.y if not lid else clampf(coordinate.y,-1.0,1.0))
		var y := side_y * r * (.0040 if side_y > 0.0 else .0028)
		var outer := absf(coordinate.y) > 1.0
		if outer:
			y += signf(y)*(.0023 + .0012*r)
		var at := face_at(center.x+x,center.y+y+signf(center.x)*x*.05,profile)
		if not outer:
			var dome := sqrt(maxf(.012*.012 - (x*.77)*(x*.77) - y*y,0))
			at.z = minf(at.z-.0003, face_at(center.x,center.y,profile).z + .0086-dome)
			if lid:
				at.z -= .0008
		surface.set_uv(Vector2(.5+x/.024,.5+y/.024))
		if not outer:
			at.y = lerpf(at.y, center.y - .0014 + signf(center.x)*x*.05, blink * .995)
		surface.set_uv2(Vector2.ZERO)
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
