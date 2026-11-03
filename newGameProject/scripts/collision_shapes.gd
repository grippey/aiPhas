class_name CollisionShapes
extends RefCounted


static func make(shape: Shape3D, pos := Vector3.ZERO) -> CollisionShape3D:
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = pos
	return col
