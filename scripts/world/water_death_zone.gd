@tool
extends Area3D

static func add_at_surface(parent: Node3D, at: Vector3, size: Vector2) -> void:
	var zone := new()
	zone.name = "WaterDeathZone"
	zone.position = at - Vector3.UP * 6
	zone.collision_layer = 0
	zone.collision_mask = 2
	zone.monitorable = false
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, 12, size.y)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	zone.add_child(collider)
	parent.add_child(zone, true)

func _ready() -> void:
	if not Engine.is_editor_hint():
		body_entered.connect(_drown)

func _drown(body: Node3D) -> void:
	if body.has_method("die"):
		body.die(&"water")
