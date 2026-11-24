extends RefCounted

enum Finish { WOOL, SKIN, HAIR, LEATHER, METAL, COTTON, EYE, FACE, FELT }

const SURFACE := preload("res://materials/characters/character_surface.gdshader")
const ROUGHNESS := [0.90, 0.78, 0.82, 0.58, 0.42, 0.94, 0.22, 0.78, 0.94]
const SPECULAR := [0.12, 0.20, 0.16, 0.28, 0.52, 0.10, 0.34, 0.20, 0.12]

static var _materials: Dictionary = {}


static func get_material(color: Color, finish: Finish = Finish.WOOL) -> Material:
	var key := "%d/%s" % [finish, color.to_html(false)]
	if _materials.has(key):
		return _materials[key]
	var material: Material
	if finish == Finish.METAL:
		var metal := StandardMaterial3D.new()
		metal.albedo_color = color
		metal.metallic = 0.76
		metal.roughness = ROUGHNESS[finish]
		metal.metallic_specular = 0.52
		material = metal
	else:
		var surface := ShaderMaterial.new()
		surface.shader = SURFACE
		surface.set_shader_parameter("tint", color)
		surface.set_shader_parameter("finish", finish)
		surface.set_shader_parameter("base_roughness", ROUGHNESS[finish])
		surface.set_shader_parameter("base_specular", SPECULAR[finish])
		material = surface
	_materials[key] = material
	return material
