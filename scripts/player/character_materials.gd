extends RefCounted

enum Finish { WOOL, SKIN, HAIR, LEATHER, METAL }

const SURFACE := preload("res://materials/characters/character_surface.gdshader")
const ROUGHNESS := [0.88, 0.72, 0.76, 0.52]
const SPECULAR := [0.14, 0.24, 0.17, 0.32]

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
		metal.roughness = 0.36
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
