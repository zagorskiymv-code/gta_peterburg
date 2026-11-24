extends RefCounted

enum Outfit { DEFAULT, FROCK_COAT, OVERCOAT, LADY_IN_DRESS, LADY_IN_CAPE, SENTRY, PATROLMAN,
	WORKER, MERCHANT, CLERK, TOWNSWOMAN, ELDER, VENDOR }

enum Hat { BOWLER, CAP, BARE, TOP_HAT, LADIES_HAT, BONNET, FORAGE_CAP }

const G = preload("res://scripts/world/district_geometry.gd")
const Materials = preload("res://scripts/player/character_materials.gd")
const Visual = preload("res://scripts/player/historical_character_visual.gd")
const PRESETS := {
	Outfit.FROCK_COAT: [0.68, 1.04, Hat.TOP_HAT, "#252b35", "#d0c2ab", "#32343c"],
	Outfit.OVERCOAT: [0.65, 1.02, Hat.BOWLER, "#665044", "#8a5341", "#35363a"],
	Outfit.LADY_IN_DRESS: [0.66, 0.96, Hat.LADIES_HAT, "#60354d", "#ac6b76", "#5d3c4d"],
	Outfit.LADY_IN_CAPE: [0.66, 0.97, Hat.LADIES_HAT, "#c3ae91", "#b88766", "#65556b"],
	Outfit.SENTRY: [1.0, 1.04, Hat.FORAGE_CAP, "#253c34", "#923f37", "#272b2d"],
	Outfit.PATROLMAN: [1.0, 1.0, Hat.FORAGE_CAP, "#394b40", "#753e38", "#2f3333"],
	Outfit.WORKER: [1.0, 1.0, Hat.CAP, "#685544", "#9d8968", "#4c493f"],
	Outfit.MERCHANT: [0.70, 1.01, Hat.BOWLER, "#523b33", "#ae8044", "#413b35"],
	Outfit.CLERK: [1.0, 0.99, Hat.BOWLER, "#4c5860", "#807266", "#383e42"],
	Outfit.TOWNSWOMAN: [0.66, 0.94, Hat.BONNET, "#4e635d", "#c0a57c", "#474c56"],
	Outfit.ELDER: [0.84, 0.94, Hat.BARE, "#776a57", "#87634c", "#514c43"],
	Outfit.VENDOR: [1.0, 0.98, Hat.CAP, "#735246", "#bbab8c", "#50423a"],
}

var _cloth: Material
var _accent: Material
var _leather := Materials.get_material(Color("#322821"), Materials.Finish.LEATHER)
var _brass := Materials.get_material(Color("#af8750"), Materials.Finish.METAL)
var _linen := Materials.get_material(Color("#c7bda5"), Materials.Finish.COTTON)


func dress(visual: Visual, outfit: Outfit, hat_override: int, coat: Color, vest: Color, trousers: Color) -> float:
	var preset: Array = PRESETS[outfit]
	var coat_tint := coat if coat.a > 0.0 else Color(preset[3])
	var accent_tint := vest if vest.a > 0.0 else Color(preset[4])
	var trousers_tint := trousers if trousers.a > 0.0 else Color(preset[5])
	_cloth = Materials.get_material(coat_tint)
	_accent = Materials.get_material(accent_tint)
	var upper := visual.upper_body
	var replacements := {
		upper.get_node("CoatTorso").material_override: _cloth,
		upper.get_node("LeftLapel").material_override: Materials.get_material(coat_tint.lightened(0.035)),
		upper.get_node("Waistcoat").material_override: _accent,
		visual.legs[0].get_node("Thigh").material_override: Materials.get_material(trousers_tint),
	}
	for mesh: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
		if mesh.material_override in replacements:
			mesh.material_override = replacements[mesh.material_override]
	_portrait(visual, outfit)
	var style: Hat = preset[2] if hat_override < 0 else hat_override
	_headwear(visual.head, style, outfit)

	if outfit in [Outfit.LADY_IN_DRESS, Outfit.LADY_IN_CAPE, Outfit.TOWNSWOMAN]:
		_dress(visual, outfit)
	elif outfit in [Outfit.SENTRY, Outfit.PATROLMAN]:
		_uniform(visual, outfit == Outfit.SENTRY)
	else:
		_civilian(visual, outfit)

	var build := Vector2.ONE
	match outfit:
		Outfit.MERCHANT, Outfit.OVERCOAT:
			build = Vector2(1.13, 1.12)
		Outfit.WORKER, Outfit.SENTRY:
			build = Vector2(1.07, 1.04)
		Outfit.CLERK, Outfit.ELDER:
			build = Vector2(.92, .96)
		Outfit.LADY_IN_DRESS, Outfit.TOWNSWOMAN:
			build = Vector2(.95, 1.02)
	visual.scale = Vector3(build.x, 1.0, build.y) * float(preset[1])
	return preset[0]


func _portrait(visual: Visual, outfit: Outfit) -> void:
	var face := 0
	var complexion := Color("#ad785e")
	var hair := Color("#413026")
	match outfit:
		Outfit.MERCHANT, Outfit.OVERCOAT:
			face = 1
			complexion = Color("#b67d64")
			hair = Color("#4c3429")
		Outfit.FROCK_COAT, Outfit.CLERK:
			face = 2
			complexion = Color("#ba8972")
			hair = Color("#534038")
		Outfit.WORKER, Outfit.SENTRY, Outfit.PATROLMAN, Outfit.VENDOR:
			face = 3
			complexion = Color("#a66f56")
			hair = Color("#3c2d27")
		Outfit.LADY_IN_DRESS, Outfit.LADY_IN_CAPE, Outfit.TOWNSWOMAN:
			face = 4
			complexion = Color("#bc8c76")
			hair = Color("#51382c") if outfit == Outfit.LADY_IN_CAPE else Color("#3d3029")
		Outfit.ELDER:
			face = 5
			complexion = Color("#a77c6c")
			hair = Color("#827b72")
	visual.configure_portrait(face, complexion, hair)
	var skin := Materials.get_material(complexion, Materials.Finish.SKIN)
	for elbow in visual.elbows:
		for name in ["Hand", "Thumb"]:
			elbow.get_node(name).material_override = skin
	if outfit in [Outfit.CLERK, Outfit.WORKER, Outfit.VENDOR]:
		visual.head.get_node("Moustache").hide()


func _headwear(head: Node3D, style: Hat, outfit: Outfit) -> void:
	var brim: MeshInstance3D = head.get_node("BowlerBrim")
	var crown: MeshInstance3D = head.get_node("BowlerCrown")
	var band: MeshInstance3D = head.get_node("BowlerBand")
	if style in [Hat.CAP, Hat.FORAGE_CAP, Hat.LADIES_HAT, Hat.BONNET]:
		brim.mesh = brim.get_meta(&"solid_brim")
	match style:
		Hat.TOP_HAT:
			brim.scale = Vector3(0.27, 0.025, 0.29)
			_cylinder(head, "SilkTopHat", Vector3(0, 0.345, 0.003), 0.202, 0.101, 0.091, Materials.get_material(Color("#2c2b2c")))
			crown.hide()
			band.scale = Vector3(0.184, 0.030, 0.184)
			band.position = Vector3(0, 0.260, 0.003)
		Hat.CAP, Hat.FORAGE_CAP:
			var service := style == Hat.FORAGE_CAP
			crown.hide()
			band.hide()
			var cap := _cylinder(head, "CapCrown", Vector3(0, 0.275, 0.002), 0.084 if service else 0.063, 0.115, 0.094, _cloth)
			cap.rotation.x = -0.10 if not service else 0.0
			if service:
				_cylinder(head, "ColoredCapBand", Vector3(0, 0.241, 0), 0.039, 0.096, 0.094, _accent)
				G.box(head, "Cockade", Vector3(0, 0.255, -0.101), Vector3(0.022, 0.027, 0.013), _brass)
				# The sentry wears a visorless lower-rank forage cap.
				brim.visible = outfit == Outfit.PATROLMAN
			brim.position.z = -0.082
			brim.scale = Vector3(0.181, 0.022, 0.143)
		Hat.LADIES_HAT, Hat.BONNET:
			brim.material_override = _accent
			brim.rotation.z = -0.12
			brim.scale = Vector3(0.38, 0.033, 0.35) if style == Hat.LADIES_HAT else Vector3(0.23, 0.035, 0.27)
			crown.material_override = _cloth
			crown.scale = Vector3(0.179, 0.126, 0.18)
			band.hide()
			if style == Hat.LADIES_HAT:
				var ribbon := G.box(head, "HatRibbon", Vector3(0.094, 0.283, -0.027), Vector3(0.12, 0.040, 0.062), _linen)
				ribbon.rotation.z = 0.5
			else:
				_cylinder(head, "BonnetBack", Vector3(0, 0.175, 0.065), 0.179, 0.085, 0.067, _cloth)
		Hat.BARE:
			brim.hide()
			crown.hide()
			band.hide()


func _dress(visual: Visual, outfit: Outfit) -> void:
	var upper := visual.upper_body
	_hide_parts(upper, ["CoatHem", "BackVent", "BackWaistSeam", "LeftBackButton", "RightBackButton", "LeftLapel",
			"RightLapel", "LeftPocketWelt", "RightPocketWelt", "Cravat", "Waistcoat",
			"WaistcoatButton0", "WaistcoatButton1", "WaistcoatButton2", "WaistcoatButton3"])
	visual.head.get_node("Moustache").hide()

	var bodice: MeshInstance3D = upper.get_node("CoatTorso")
	bodice.mesh = bodice.get_meta(&"closed_cut")
	bodice.scale.x = 0.365
	upper.get_node("CoatShoulders").hide()
	upper.get_node("CoatShoulders").scale.x = 0.365
	for arm in visual.arms:
		arm.position.x *= 0.92
		arm.get_node("Shoulder").scale *= 1.22
	for leg in visual.legs:
		_hide_parts(leg, ["Thigh", "Knee/KneeVolume", "Knee/TrouserLeg", "Knee/BootShaft"])
		# Only ankle footwear is rendered. The skirt rides on the hips, independent of torso lean.
		for shoe: MeshInstance3D in leg.get_node("Knee/Ankle").get_children():
			shoe.scale.x *= 0.90
	var skirt_color: Material = _cloth
	if outfit == Outfit.LADY_IN_CAPE:
		skirt_color = Materials.get_material(Color("#635567"))
	var skirt := _cylinder(visual.body, "LongSkirt", Vector3(0, -0.324, 0.006), 0.82, 0.160, 0.358, skirt_color, 0.95)
	skirt.mesh.radial_segments = 14
	var hem := _cylinder(visual.body, "SkirtHemBand", Vector3(0, -0.705, 0.006), 0.045, 0.357, 0.368, _accent, 0.95)
	hem.mesh.radial_segments = 14
	_cylinder(upper, "WaistSash", Vector3(0, 0.084, 0), 0.059, 0.180, 0.181, _accent, 0.94)
	if outfit == Outfit.LADY_IN_CAPE:
		_cylinder(upper, "ShoulderCape", Vector3(0, 0.389, 0.01), 0.34, 0.107, 0.265, _cloth, 0.69)
		G.box(upper, "CapeClasp", Vector3(0, 0.411, -0.151), Vector3(0.040, 0.044, 0.02), _brass)
	elif outfit == Outfit.TOWNSWOMAN:
		G.box(upper, "HouseholdPouch", Vector3(0.117, 0.022, -0.153), Vector3(0.115, 0.121, 0.075), _leather)
	else:
		_gloves(visual)


func _uniform(visual: Visual, sentry: bool) -> void:
	var upper := visual.upper_body
	var tunic: MeshInstance3D = upper.get_node("CoatTorso")
	tunic.mesh = tunic.get_meta(&"closed_cut")
	upper.get_node("CoatShoulders").hide()
	_hide_parts(upper, ["LeftLapel", "RightLapel", "LeftCollar", "RightCollar", "Cravat", "Waistcoat",
			"ShirtFront", "WaistcoatButton0", "WaistcoatButton1", "WaistcoatButton2", "WaistcoatButton3"])
	_cylinder(upper, "StandCollar", Vector3(0, 0.505, 0), 0.091, 0.069, 0.081, _accent, 0.9)
	_cylinder(upper, "LeatherBelt", Vector3(0, 0.094, 0.008), 0.063, 0.172, 0.17, _leather, 0.84)
	G.box(upper, "Buckle", Vector3(0, 0.095, -0.143), Vector3(0.070, 0.048, 0.024), _brass)
	for sign_x in [-1.0, 1.0]:
		var board := G.box(upper, "ShoulderStrap", Vector3(sign_x * 0.151, 0.536, 0.006), Vector3(0.123, 0.029, 0.067), _accent)
		board.rotation.z = -sign_x * 0.17
		G.box(upper, "StrapButton", Vector3(sign_x * 0.116, 0.556, -0.01), Vector3(0.017, 0.011, 0.018), _brass)
	for leg in visual.legs:
		var boot: MeshInstance3D = leg.get_node("Knee/BootShaft")
		boot.show()
		boot.position.y = -0.25
		boot.scale = Vector3(0.157, 0.347, 0.153)
		var trouser_leg: MeshInstance3D = leg.get_node("Knee/TrouserLeg")
		trouser_leg.position.y = -0.056
		trouser_leg.scale.y = 0.16
	if sentry:
		_gloves(visual)
	else:
		var strap := G.box(upper, "SatchelStrap", Vector3(0, 0.298, -0.148), Vector3(0.050, 0.46, 0.022), _leather)
		strap.rotation.z = 0.47
		G.box(upper, "LeatherPouch", Vector3(0.148, 0.059, 0.121), Vector3(0.161, 0.158, 0.088), _leather)


func _civilian(visual: Visual, outfit: Outfit) -> void:
	var upper := visual.upper_body
	match outfit:
		Outfit.FROCK_COAT, Outfit.OVERCOAT, Outfit.MERCHANT:
			_hide_parts(upper, ["CoatHem", "BackVent"])
			var length := 0.53 if outfit == Outfit.OVERCOAT else 0.42
			var coat_skirts := _cylinder(visual.body, "CoatSkirts", Vector3(0, 0.087 - length * 0.5, 0.012),
					length, 0.194, 0.313, _cloth, 1.29)
			coat_skirts.mesh.radial_segments = 14
			if outfit == Outfit.MERCHANT:
				G.box(visual.elbows[1], "MerchantLedger", Vector3(0.044, -0.298, -0.026), Vector3(0.047, 0.177, 0.14), _accent)
			else:
				_gloves(visual)
				if outfit == Outfit.OVERCOAT:
					_cylinder(upper, "TurnedOvercoatCollar", Vector3(0, 0.453, 0.003), 0.161, 0.103, 0.192, _accent, 0.72)
		Outfit.VENDOR:
			_cylinder(upper, "ApronTies", Vector3(0, 0.098, 0.003), 0.038, 0.169, 0.168, _accent, 0.86)
			G.box(upper, "ApronBib", Vector3(0, 0.245, -0.160), Vector3(0.202, 0.336, 0.037), _accent)
			var apron := G.box(upper, "ApronSkirt", Vector3(0, -0.116, -0.211), Vector3(0.306, 0.423, 0.032), _accent)
			apron.rotation.x = 0.25
			G.box(apron, "ApronPocket", Vector3(0.045, 0.019, -0.021), Vector3(0.137, 0.101, 0.024), _linen)
		Outfit.WORKER:
			_hide_parts(upper, ["Cravat", "LeftLapel", "RightLapel"])
			for sign_x in [-1.0, 1.0]:
				G.box(upper, "WorkSuspender", Vector3(sign_x * 0.095, 0.285, -0.150), Vector3(0.047, 0.35, 0.03), _accent)
			G.box(visual.elbows[1], "WorkBag", Vector3(0.075, -0.325, -0.004), Vector3(0.115, 0.226, 0.183), _leather)
		Outfit.CLERK:
			G.box(visual.elbows[0], "DocumentCase", Vector3(-0.075, -0.305, 0), Vector3(0.075, 0.227, 0.190), _leather)
		Outfit.ELDER:
					_cylinder(upper, "WoolScarf", Vector3(0, 0.484, 0), 0.095, 0.088, 0.107, _accent)


func _gloves(visual: Visual) -> void:
	for elbow in visual.elbows:
		for path in ["Hand", "Thumb"]:
			elbow.get_node(path).material_override = _leather


func _hide_parts(anchor: Node3D, paths: Array) -> void:
	for path in paths:
		anchor.get_node(path).hide()


func _cylinder(anchor: Node3D, title: String, center: Vector3, height: float, top: float, bottom: float,
		material: Material, depth := 1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.radial_segments = 10
	mesh.rings = 0
	mesh.height = height
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	var part := G.mesh_part(anchor, title, center, mesh, material)
	part.scale.z = depth
	return part
