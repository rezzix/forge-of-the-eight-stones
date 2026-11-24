extends MeshInstance3D
## Very small helper: makes a mesh spin forever (used for the Forge crystal).

@export var spin_speed := 1.2

func _process(delta: float) -> void:
	rotation.y += spin_speed * delta
	rotation.x += spin_speed * 0.35 * delta
